import Foundation
import Testing
#if canImport(CuentivaCore)
@testable import CuentivaCore
#else
@testable import Cuentiva
#endif

private actor ChatTestRepository: ChatRepository {
    var values: [String: ChatConversation] = [:]
    var fail = false
    var pauseLoad = false
    var loadFailure = false
    var loadContinuation: CheckedContinuation<Void, Never>?
    func configureLoad(paused: Bool = false, fail: Bool = false) {
        pauseLoad = paused; loadFailure = fail
    }
    func waitingToLoad() -> Bool { loadContinuation != nil }
    func resumeLoad() { loadContinuation?.resume(); loadContinuation = nil }
    func load() async throws -> [String: ChatConversation] {
        if pauseLoad { await withCheckedContinuation { loadContinuation = $0 } }
        if loadFailure { throw AppFailure.unavailable("Unreadable history") }
        return values
    }
    func save(_ value: [String: ChatConversation]) throws {
        if fail { throw AppFailure.unavailable("Disk full") }
        values = value
    }
    func setFailure() { fail = true }
}
private actor ChatTestGenerator: ChatGenerator {
    var requests: [ChatRequest] = []
    var unavailable: String?
    var paused = false
    var pending: CheckedContinuation<Void, Never>?
    func availabilityMessage() -> String? { unavailable }
    func configure(unavailable: String? = nil, paused: Bool = false) {
        self.unavailable = unavailable; self.paused = paused
    }
    func resume() { pending?.resume(); pending = nil }
    func isWaiting() -> Bool { pending != nil }
    func reply(to request: ChatRequest) async -> ChatReply {
        requests.append(request)
        if paused { await withCheckedContinuation { pending = $0 } }
        return .init(spanish: "¡Hola! ¿Dónde vive el dragón?", english: "Hello! Where does the dragon live?",
                     correction: "", suggestion: "Vive en el bosque.", memory: "Discussing a dragon in a forest.")
    }
}
@Suite @MainActor struct ChatTests {
    private let author = Author.demoProfiles[0]
    @Test func concurrentPreparationWaitsForSameLoad() async throws {
        let purchases = TestPurchases(), repository = ChatTestRepository()
        await repository.configureLoad(paused: true)
        let chat = ChatManager(purchases: purchases, generator: ChatTestGenerator(), repository: repository)
        let first = Task { try await chat.prepare() }
        while !(await repository.waitingToLoad()) { await Task.yield() }
        var secondStarted = false
        var secondFinished = false
        let second = Task {
            secondStarted = true
            try await chat.prepare()
            secondFinished = true
        }
        while !secondStarted { await Task.yield() }
        #expect(!secondFinished)
        #expect(chat.preparing)
        await repository.resumeLoad()
        try await first.value
        try await second.value
        #expect(chat.ready)
        #expect(!chat.preparing)
        #expect(purchases.refreshCalls == 1)
    }
    @Test func featureRejectsPurchaseOnUnsupportedDevice() async throws {
        let purchases = TestPurchases(), generator = ChatTestGenerator()
        await generator.configure(unavailable: "Unsupported device")
        let chat = ChatManager(purchases: purchases, generator: generator, repository: ChatTestRepository())
        await #expect(throws: AppFailure.self) { try await chat.purchase() }
        #expect(!purchases.hasAccess)
    }
    @Test func modelBecomingUnavailablePreventsPurchaseAfterPreparation() async throws {
        let purchases = TestPurchases(), generator = ChatTestGenerator()
        let chat = ChatManager(purchases: purchases, generator: generator, repository: ChatTestRepository())
        try await chat.prepare()
        await generator.configure(unavailable: "Model no longer available")
        await #expect(throws: AppFailure.self) { try await chat.purchase() }
        #expect(!purchases.hasAccess)
    }
    @Test func restoreWorksDespiteLocalHistoryFailure() async throws {
        let purchases = TestPurchases(), repository = ChatTestRepository()
        purchases.restoresAccess = true
        await repository.configureLoad(fail: true)
        let chat = ChatManager(purchases: purchases, generator: ChatTestGenerator(), repository: repository)
        await #expect(throws: AppFailure.self) { try await chat.prepare() }
        #expect(!chat.ready)
        #expect(!chat.preparing)
        try await chat.restore()
        #expect(chat.hasAccess)
    }
    @Test func prepareCanRetryAfterLocalFailure() async throws {
        let repository = ChatTestRepository()
        await repository.configureLoad(fail: true)
        let chat = ChatManager(purchases: TestPurchases(), generator: ChatTestGenerator(), repository: repository)
        await #expect(throws: AppFailure.self) { try await chat.prepare() }
        await repository.configureLoad()
        try await chat.prepare()
        #expect(chat.ready)
    }
    @Test func noGenerationBeforeSeparatePurchase() async throws {
        let purchases = TestPurchases(), generator = ChatTestGenerator(), repository = ChatTestRepository()
        let chat = ChatManager(purchases: purchases, generator: generator, repository: repository)
        try await chat.prepare()
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(await generator.requests.isEmpty)
        #expect(await repository.values.isEmpty)
    }
    @Test func unsupportedDeviceDoesNotGenerateEvenIfPurchased() async throws {
        let purchases = TestPurchases(), generator = ChatTestGenerator()
        purchases.hasAccess = true
        await generator.configure(unavailable: "Model not ready")
        let chat = ChatManager(purchases: purchases, generator: generator, repository: ChatTestRepository())
        try await chat.prepare()
        #expect(chat.unavailable == "Model not ready")
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(await generator.requests.isEmpty)
    }
    @Test func conversationPersistsAndContextRemainsBounded() async throws {
        let purchases = TestPurchases(), generator = ChatTestGenerator(), repository = ChatTestRepository()
        purchases.hasAccess = true
        let chat = ChatManager(purchases: purchases, generator: generator, repository: repository)
        try await chat.prepare()
        for n in 0..<6 { try await chat.send("Hola \(n)", to: author, level: "B1") }
        let requests = await generator.requests
        #expect(requests.last?.recent.count == 2)
        #expect(requests.last?.memory == "Discussing a dragon in a forest.")
        #expect(requests.last?.level == "B1")
        let restored = ChatManager(purchases: purchases, generator: generator, repository: repository)
        try await restored.prepare()
        #expect(restored.conversation(for: author).turns.count == 6)
        purchases.hasAccess = false
        #expect(restored.conversation(for: author).turns.isEmpty)
    }
    @Test func failedSaveDoesNotAppendConversation() async throws {
        let purchases = TestPurchases(), repository = ChatTestRepository()
        purchases.hasAccess = true
        let chat = ChatManager(purchases: purchases, generator: ChatTestGenerator(), repository: repository)
        try await chat.prepare()
        await repository.setFailure()
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(chat.conversation(for: author).turns.isEmpty)
        #expect(!chat.busy)
    }
    @Test func revocationWhileGeneratingDiscardsReplyAndRejectsOverlap() async throws {
        let purchases = TestPurchases(), generator = ChatTestGenerator(), repository = ChatTestRepository()
        purchases.hasAccess = true
        await generator.configure(paused: true)
        let chat = ChatManager(purchases: purchases, generator: generator, repository: repository)
        try await chat.prepare()
        let task = Task { try await chat.send("Hola", to: author, level: "A2") }
        while !(await generator.isWaiting()) { await Task.yield() }
        await #expect(throws: AppFailure.self) { try await chat.send("Otro", to: author, level: "A2") }
        purchases.hasAccess = false
        await generator.resume()
        await #expect(throws: AppFailure.self) { try await task.value }
        #expect(await repository.values.isEmpty)
        #expect(!chat.busy)
    }
    @Test func cancelledGenerationDoesNotSave() async throws {
        let purchases = TestPurchases(), generator = ChatTestGenerator(), repository = ChatTestRepository()
        purchases.hasAccess = true
        await generator.configure(paused: true)
        let chat = ChatManager(purchases: purchases, generator: generator, repository: repository)
        try await chat.prepare()
        let task = Task { try await chat.send("Hola", to: author, level: "A2") }
        while !(await generator.isWaiting()) { await Task.yield() }
        task.cancel()
        await generator.resume()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await repository.values.isEmpty)
        #expect(!chat.busy)
    }
    @Test func clearingOneStorytellerPreservesAnother() async throws {
        let purchases = TestPurchases(), repository = ChatTestRepository()
        purchases.hasAccess = true
        let chat = ChatManager(purchases: purchases, generator: ChatTestGenerator(), repository: repository)
        try await chat.prepare()
        let other = Author.demoProfiles[1]
        try await chat.send("Hola", to: author, level: "A1")
        try await chat.send("Hola", to: other, level: "A1")
        try await chat.clear(author: author)
        #expect(chat.conversation(for: author).turns.isEmpty)
        #expect(chat.conversation(for: other).turns.count == 1)
        #expect(await repository.values[author.id] == nil)
    }
    @Test func rejectsOversizedMessagesBeforeInference() async throws {
        let purchases = TestPurchases(), generator = ChatTestGenerator()
        purchases.hasAccess = true
        let chat = ChatManager(purchases: purchases, generator: generator, repository: ChatTestRepository())
        try await chat.prepare()
        await #expect(throws: AppFailure.self) { try await chat.send(String(repeating: "a", count: 501), to: author, level: "A2") }
        #expect(await generator.requests.isEmpty)
    }
}
