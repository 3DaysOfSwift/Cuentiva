import Foundation
import Testing
import StoreKit
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
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

    @Test(arguments: [false, true])
    func progressLoadIsSharedAndFailureCanRetry(failFirst: Bool) async throws {
        let repository = ProgressReadGate()
        let progress = ProgressManager(repository: repository)
        let first = Task { try await progress.load() }
        defer { repository.finish(); first.cancel() }
        try await waitUntil { repository.pending != nil }
        var secondEntered = false
        let second = Task { secondEntered = true; try await progress.load() }
        defer { second.cancel() }
        try await waitUntil { secondEntered }
        #expect(repository.reads == 1)
        first.cancel()
        repository.finish(failing: failFirst)
        if failFirst {
            await #expect(throws: AppFailure.self) { try await first.value }
            await #expect(throws: AppFailure.self) { try await second.value }
            #expect(!progress.loaded)
            let retry = Task { try await progress.load() }
            defer { repository.finish(); retry.cancel() }
            try await waitUntil { repository.pending != nil }
            repository.finish()
            try await retry.value
            #expect(repository.reads == 2)
        } else {
            try await first.value
            try await second.value
        }
        #expect(progress.loaded)
        #expect(progress.snapshot.completed == ["cafe"])
        let reads = repository.reads
        try await progress.load()
        #expect(repository.reads == reads)
    }

    @Test func purchaseRefreshWaitersShareTheWholeOperationAndRetryAfterFailure() async throws {
        let gate = PurchaseRefreshGate()
        let purchases = PurchaseManager(readEntitlements: {
            await gate.readEntitlements()
        }, readLatest: { _ in nil }, loadProducts: { _ in
            try await gate.products()
        }, observesTransactions: false)
        var firstFinished = false
        let first = Task { await purchases.refresh(); firstFinished = true }
        try await waitUntil { gate.reading != nil }
        var secondEntered = false
        var secondFinished = false
        let second = Task {
            secondEntered = true
            await purchases.refresh()
            secondFinished = true
        }
        try await waitUntil { secondEntered }
        #expect(!secondFinished)
        #expect(gate.readCount == 1)
        first.cancel()
        gate.releaseEntitlements()
        try await waitUntil { gate.pricing != nil }
        #expect(!firstFinished && !secondFinished)
        #expect(!gate.sharedOperationWasCancelled)
        gate.releaseProducts()
        await first.value; await second.value
        #expect(firstFinished && secondFinished)
        #expect(!purchases.checking)
        #expect(purchases.message != nil)
        #expect(gate.productCount == 1)
        // Failure must clear the shared operation so a later explicit retry runs.
        await purchases.refresh()
        #expect(gate.readCount == 2)
        #expect(gate.productCount == 2)
    }

    @Test func bookQueriesSkipDiscoveryAndFiltersReuseSharedPreparation() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: [sample(), sample("two")]), purchases: purchases, progress: progress)
        try await progress.load()
        try await library.load()
        let initial = library.revision
        #expect(library.revision == initial)
        _ = await library.matchingBooks(.init(completedOnly: true))
        _ = await library.books(by: Author.demoProfiles[0])
        #expect(await library.discoveryBuildCount == 0)
        #expect(await library.recommendationBuildCount == 0)
        _ = await library.presentation(.init(recommendations: true))
        _ = await library.presentation(.init(text: "cafe"))
        _ = await library.presentation(.init(level: "B1"))
        #expect(await library.discoveryBuildCount == 1)
        #expect(library.revision == initial)
        try await progress.setVocabulary("café", state: .known)
        #expect(library.revision != initial)
        _ = await library.presentation(.init())
        #expect(await library.discoveryBuildCount == 2)
        purchases.hasAccess = false
        #expect(await library.matchingBooks(.init()).isEmpty)
    }

    @Test func personalRevisionChangesWithoutPreparingBooksOnTheUIActor() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let personal = RawPersonalLibrary()
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: [sample()]), purchases: purchases, progress: progress,
            personalLibrary: personal)
        try await progress.load()
        try await library.load()
        let before = library.revision
        _ = library.revision
        _ = await library.presentation(.init())
        #expect(personal.legacyGetterCalls == 0)
        let author = Author.demoProfiles[0]
        var personalBook = sample("personal")
        personalBook.personalAuthor = author
        personal.libraryContent = .init(publications: [.init(storyID: UUID(), publishedAt: .now, book: personalBook)], author: author)
        personal.libraryRevision = UUID()
        #expect(library.revision != before)
        #expect(await library.matchingBooks(.init()).first?.id == "personal")
        #expect(personal.legacyGetterCalls == 0)
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
        initial.completed = Set((0..<11).map { "earned-\($0)" })
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
        initial.completed = Set((0..<11).map { "earned-\($0)" })
        let store = GatedProgressRepository(initial)
        let progress = ProgressManager(repository: store); try await progress.load()
        let author = Author.demoProfiles[0]
        let chat = ChatManager(generator: ImmediateChatGenerator(), progress: progress)
        try await chat.prepare()
        let session = UUID(); chat.beginSession(id: session, author: author)
        if chat.hasAccess { try chat.authorizeSession() }
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
        if reopened.hasAccess { try reopened.authorizeSession() }
        try await reopened.send("Otro tema", to: author, level: "A2")
        #expect(reopened.coins == 0)
        #expect(reopened.conversation(for: author).turns.count == 1)
        #expect(reloaded.snapshot.pendingChatAdmission == false)
        #expect(await store.writes.count == 2)
    }

    @Test func failedSettlementPreservesCreditRatherThanLosingPayment() async throws {
        var initial = LearnerProgress(); initial.doubloons = 1
        initial.completed = Set((0..<11).map { "earned-\($0)" })
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


}

private actor ImmediateChatGenerator: ChatGenerator {
    func availabilityMessage() -> String? { nil }
    func reply(to request: ChatRequest) -> ChatReply {
        .init(spanish: "Hola, ¿cómo estás?", english: "Hello, how are you?",
            correction: "", suggestion: "Muy bien.", memory: "Greetings")
    }
}

@MainActor private final class PurchaseRefreshGate {
    var reading: CheckedContinuation<Void, Never>?
    var pricing: CheckedContinuation<Void, Never>?
    var readCount = 0
    var productCount = 0
    var sharedOperationWasCancelled = false
    func readEntitlements() async -> [VerificationResult<StoreKit.Transaction>] {
        readCount += 1
        if readCount == 1 { await withCheckedContinuation { reading = $0 } }
        sharedOperationWasCancelled = Task.isCancelled
        return []
    }
    func products() async throws -> [Product] {
        productCount += 1
        if productCount == 1 {
            await withCheckedContinuation { pricing = $0 }
            throw AppFailure.unavailable("Injected pricing failure")
        }
        return []
    }
    func releaseEntitlements() { reading?.resume(); reading = nil }
    func releaseProducts() { pricing?.resume(); pricing = nil }
}

@MainActor private final class RawPersonalLibrary: PersonalLibraryFeature {
    var libraryRevision = UUID()
    var libraryContent = PersonalLibraryContent()
    var legacyGetterCalls = 0
    var publishedBooks: [Book] { legacyGetterCalls += 1; return libraryContent.preparedBooks() }
}

@MainActor private final class ProgressReadGate: ProgressRepository {
    var reads = 0
    var pending: CheckedContinuation<LearnerProgress, Error>?
    func load() async throws -> LearnerProgress {
        reads += 1
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func save(_ value: LearnerProgress) async throws {}
    func finish(failing: Bool = false) {
        let continuation = pending
        pending = nil
        if failing { continuation?.resume(throwing: AppFailure.unavailable("Read failed")) }
        else {
            var value = LearnerProgress()
            value.completed.insert("cafe")
            continuation?.resume(returning: value)
        }
    }
}
