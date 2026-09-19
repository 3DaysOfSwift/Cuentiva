import Foundation
import Testing
#if canImport(CuentivaCore)
@testable import CuentivaCore
#else
@testable import Cuentiva
#endif

/// An explicit I/O gate makes overlap deterministic without timing a disk write.
private actor GatedProgressRepository: ProgressRepository {
    private var value: LearnerProgress
    private var pauseNext = true
    private var pending: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    private var failNext = false
    private var failOnSave: Int?
    private var saveNumber = 0
    private(set) var writes: [LearnerProgress] = []
    init(_ value: LearnerProgress = .init(), failOnSave: Int? = nil) { self.value = value; self.failOnSave = failOnSave }
    func load() -> LearnerProgress { value }
    func save(_ next: LearnerProgress) async throws {
        saveNumber += 1
        if pauseNext {
            pauseNext = false
            await withCheckedContinuation { continuation in
                pending = continuation
                observer?.resume(); observer = nil
            }
        }
        if failNext || saveNumber == failOnSave { failNext = false; throw AppFailure.unavailable("Test storage failure") }
        value = next; writes.append(next)
    }
    func waitForSave() async {
        if pending != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func release(failing: Bool = false) {
        failNext = failing
        pending?.resume(); pending = nil
    }
}

@Suite(.timeLimit(.minutes(1))) @MainActor struct ConcurrencyTests {
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw AppFailure.unavailable("Test operation did not reach its gate.") }
            await Task.yield()
        }
    }

    @Test func savesAreFIFOAndUseLatestCommittedState() async throws {
        let store = GatedProgressRepository()
        let progress = ProgressManager(repository: store); try await progress.load()
        let first = Task { try await progress.setVocabulary("uno", state: .learning) }
        await store.waitForSave()
        let second = Task { try await progress.setVocabulary("uno", state: .known) }
        try await waitUntil { progress.queuedSaveCount == 1 }
        let third = Task { try await progress.setVocabulary("dos", state: .known) }
        try await waitUntil { progress.queuedSaveCount == 2 }
        await store.release()
        try await first.value; try await second.value; try await third.value
        let writes = await store.writes
        #expect(writes.map { $0.vocabulary["uno"] } == [.learning, .known, .known])
        #expect(progress.snapshot.vocabulary == ["uno": .known, "dos": .known])
        #expect(await store.load() == progress.snapshot)
    }

    @Test func failedSaveDoesNotPoisonQueueAndCancelledWaiterDoesNotWrite() async throws {
        let store = GatedProgressRepository()
        let progress = ProgressManager(repository: store); try await progress.load()
        let first = Task { try await progress.setVocabulary("failed", state: .known) }
        await store.waitForSave()
        let cancelled = Task { try await progress.setVocabulary("cancelled", state: .known) }
        try await waitUntil { progress.queuedSaveCount == 1 }
        cancelled.cancel()
        let last = Task { try await progress.setVocabulary("saved", state: .known) }
        try await waitUntil { progress.queuedSaveCount == 2 }
        await store.release(failing: true)
        await #expect(throws: AppFailure.self) { try await first.value }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        try await last.value
        #expect(progress.snapshot.vocabulary == ["saved": .known])
        #expect(await store.writes.count == 1)
    }

    @Test func overlappingCompletionsRewardOnlyOnce() async throws {
        let book = sample()
        var initial = LearnerProgress(); initial.attempts[book.id] = Set(book.sentences.map(\.id))
        let store = GatedProgressRepository(initial)
        let progress = ProgressManager(repository: store); try await progress.load()
        let first = Task { try await progress.completeReading(book: book) }
        await store.waitForSave()
        let second = Task { try await progress.completeReading(book: book) }
        try await waitUntil { progress.queuedSaveCount == 1 }
        await store.release()
        #expect(try await first.value.isNew)
        #expect(try await !second.value.isNew)
        #expect(progress.snapshot.completed.count == 1)
        #expect(progress.snapshot.doubloons == 1)
    }

    @Test func overlappingDebitsCannotSpendLastCoinTwice() async throws {
        var initial = LearnerProgress(); initial.doubloons = 1
        let store = GatedProgressRepository(initial)
        let progress = ProgressManager(repository: store); try await progress.load()
        let first = Task { try await progress.payForChat { true } }
        await store.waitForSave()
        let second = Task { try await progress.payForChat { true } }
        try await waitUntil { progress.queuedSaveCount == 1 }
        await store.release()
        try await first.value
        await #expect(throws: AppFailure.self) { try await second.value }
        #expect(progress.snapshot.doubloons == 0)
    }

    @Test(arguments: [false, true]) func dismissalDuringPaymentKeepsAdmissionAcrossRelaunch(cancelTask: Bool) async throws {
        var initial = LearnerProgress(); initial.doubloons = 1
        let store = GatedProgressRepository(initial)
        let progress = ProgressManager(repository: store); try await progress.load()
        let author = Author.demoProfiles[0]
        let chat = ChatManager(generator: ImmediateChatGenerator(), progress: progress)
        try await chat.prepare()
        let session = UUID(); chat.beginSession(id: session, author: author)
        let sending = Task { try await chat.send("Hola", to: author, level: "A2") }
        await store.waitForSave()
        chat.endSession(id: session)
        if cancelTask { sending.cancel() }
        await store.release()
        await #expect(throws: CancellationError.self) { try await sending.value }
        #expect(chat.coins == 1)
        #expect(chat.conversation(for: author).turns.isEmpty)
        let reloaded = ProgressManager(repository: store)
        let reopened = ChatManager(generator: ImmediateChatGenerator(), progress: reloaded)
        try await reopened.prepare()
        reopened.beginSession(id: UUID(), author: author)
        try await reopened.send("Otro tema", to: author, level: "A2")
        #expect(reopened.coins == 0)
        #expect(reopened.conversation(for: author).turns.count == 1)
        #expect(reloaded.snapshot.pendingChatAdmission == false)
        #expect(await store.writes.count == 2)
    }

    @Test func failedSettlementPreservesCreditRatherThanLosingPayment() async throws {
        var initial = LearnerProgress(); initial.doubloons = 1
        let store = GatedProgressRepository(initial, failOnSave: 2)
        let progress = ProgressManager(repository: store); try await progress.load()
        var delivered = false
        let payment = Task { try await progress.payForChat { delivered = true; return true } }
        await store.waitForSave(); await store.release()
        await #expect(throws: AppFailure.self) { try await payment.value }
        #expect(delivered)
        let reopened = ProgressManager(repository: store); try await reopened.load()
        #expect(reopened.snapshot.availableChatCoins == 1)
        try await reopened.payForChat { true }
        #expect(reopened.snapshot.availableChatCoins == 0)
    }

    @Test func concurrentLibraryQueriesKeepTheirOwnFiltersAndProgress() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let first = sample("first"), second = sample("second")
        let library = LibraryManager(repository: MemoryBooks(values: [first, second]), purchases: purchases, progress: progress)
        try await library.load()
        async let empty = library.presentation(.init(text: "no matching title"))
        async let all = library.presentation(.init())
        #expect(await empty.books.isEmpty)
        #expect(await all.books.count == 2)
        try await progress.recordEncounter(book: first, sentence: first.sentences[0])
        _ = try await progress.completeReading(book: first)
        async let completed = library.presentation(.init(completedOnly: true))
        async let unread = library.presentation(.init(hideCompleted: true))
        #expect(await completed.books.map(\.id) == [first.id])
        #expect(await unread.books.map(\.id) == [second.id])
    }

    @Test func interruptedAdmissionRoundTripsThroughStorageRecords() throws {
        var initial = LearnerProgress(); initial.doubloons = 0; initial.pendingChatAdmission = true
        let encoded = try ProgressRecords.encode(initial)
        let decoded = try ProgressRecords.decode(encoded)
        #expect(decoded == initial)
        #expect(decoded.availableChatCoins == 1)
    }

    @Test func locationCancellationCleansUpAndIgnoresLateCallbacks() async throws {
        let request = LocationRequest()
        var oldID: UUID?
        var cleanupCount = 0
        let old = Task { try await request.value(start: { oldID = $0 }, stop: { cleanupCount += 1 }) }
        try await waitUntil { oldID != nil }
        old.cancel()
        await #expect(throws: CancellationError.self) { try await old.value }
        #expect(cleanupCount == 1)
        var newID: UUID?
        let next = Task { try await request.value(start: { newID = $0 }, stop: { cleanupCount += 1 }) }
        try await waitUntil { newID != nil }
        request.finish(.failure(AppFailure.unavailable("Test storage failure")), id: try #require(oldID))
        #expect(request.id == newID)
        let place = StoryLocation(latitude: 1, longitude: 2, accuracy: 10, capturedAt: .now, placeName: "Test")
        request.finish(.success(place), id: try #require(newID))
        request.finish(.success(place), id: try #require(newID))
        #expect(try await next.value == place)
        #expect(cleanupCount == 2)
    }

    @Test func alreadyCancelledLocationDoesNotStartHardware() async throws {
        let request = LocationRequest()
        var started = false
        let task = Task {
            return try await request.value(start: { _ in started = true }, stop: {})
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!started)
        #expect(request.id == nil)
    }
}

private actor ImmediateChatGenerator: ChatGenerator {
    func availabilityMessage() -> String? { nil }
    func reply(to request: ChatRequest) -> ChatReply {
        .init(spanish: "Hola, ¿cómo estás?", english: "Hello, how are you?",
            correction: "", suggestion: "Muy bien.", memory: "Greetings")
    }
}
