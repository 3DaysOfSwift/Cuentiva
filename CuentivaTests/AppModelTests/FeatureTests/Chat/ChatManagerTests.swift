import Foundation
import Testing

#if canImport(CuentivaAppModel)
    @testable import CuentivaAppModel
#else
    @testable import Cuentiva
#endif

private actor ChatTestGenerator: ChatGenerator {
    var requests: [ChatRequest] = []
    var unavailable: String?
    var suppliedReply: ChatReply?
    func setReply(_ reply: ChatReply) { suppliedReply = reply }
    var paused = false
    var pending: CheckedContinuation<Void, Never>?
    func availabilityMessage() -> String? { unavailable }
    func configure(unavailable: String? = nil, paused: Bool = false) {
        self.unavailable = unavailable
        self.paused = paused
    }
    func resume() {
        pending?.resume()
        pending = nil
    }
    func isWaiting() -> Bool { pending != nil }
    func reply(to request: ChatRequest) async -> ChatReply {
        requests.append(request)
        if paused { await withCheckedContinuation { pending = $0 } }
        if let suppliedReply { return suppliedReply }
        return .init(
            spanish: "¡Hola! ¿Dónde vive el dragón?", english: "Hello! Where does the dragon live?",
            correction: "", suggestion: "Vive en el bosque.", memory: "Discussing a dragon in a forest.")
    }
}
@Suite @MainActor struct ChatTests {
    private let author = Author.demoProfiles[0]
    private func wallet(_ coins: Int = 2, repository: MemoryProgress = MemoryProgress()) async throws -> ProgressManager {
        var value = LearnerProgress(); value.doubloons = coins
        value.completed = Set((0..<11).map { "earned-\($0)" })
        try await repository.save(value)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        return progress
    }
    @Test func coinsDoNotBypassReadingUnlock() async throws {
        var value = LearnerProgress(); value.doubloons = 10
        value.completed = Set((0..<10).map { "earned-\($0)" })
        let store = MemoryProgress(); try await store.save(value)
        let progress = ProgressManager(repository: store); try await progress.load()
        let chat = ChatManager(generator: ChatTestGenerator(), progress: progress)
        try await chat.prepare()
        #expect(!progress.snapshot.chatUnlocked)
        #expect(!chat.hasAccess)
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A1") }
        #expect(progress.snapshot.availableChatCoins == 10)
        let book = sample("eleventh")
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        #expect(progress.snapshot.chatUnlocked)
        #expect(chat.hasAccess)
    }

    @Test func completionEarnsOnceAndPracticeDoesNotAwardAgain() async throws {
        let repository = MemoryProgress()
        let progress = try await wallet(0, repository: repository)
        let book = sample()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.completeReading(book: book)
        #expect(progress.snapshot.doubloons == 1)
        _ = try await progress.complete(book: book)
        #expect(progress.snapshot.doubloons == 1)
        let reloaded = ProgressManager(repository: repository); try await reloaded.load()
        _ = try await reloaded.completeReading(book: book)
        #expect(reloaded.snapshot.doubloons == 1)
        let second = sample("second")
        try await reloaded.recordEncounter(book: second, sentence: second.sentences[0])
        _ = try await reloaded.complete(book: second)
        #expect(reloaded.snapshot.doubloons == 2)
        let third = sample("third")
        try await reloaded.recordEncounter(book: third, sentence: third.sentences[0])
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await reloaded.complete(book: third) }
        #expect(reloaded.snapshot.doubloons == 2)
        #expect(!reloaded.snapshot.completed.contains("third"))
    }
    @Test func oneCoinCoversContinuousChatAndClosingRequiresAnother() async throws {
        let progress = try await wallet()
        let generator = ChatTestGenerator()
        let chat = ChatManager(generator: generator, progress: progress)
        try await chat.prepare()
        let first = UUID(); chat.beginSession(id: first, author: author)
        #expect(chat.coins == 2)
        for n in 0..<6 { try await chat.send("Hola \(n)", to: author, level: "B1") }
        #expect(chat.coins == 1)
        #expect(chat.sessionPaid)
        let requests = await generator.requests
        #expect(requests.last?.recent.count == 2)
        #expect(requests.last?.level == "B1")
        chat.endSession(id: first)
        #expect(chat.conversation(for: author).turns.isEmpty)
        #expect(!chat.sessionPaid)
        let second = UUID(); chat.beginSession(id: second, author: author)
        try await chat.send("Otro tema", to: author, level: "A2")
        #expect(chat.coins == 0)
        try await chat.send("Más", to: author, level: "A2")
        #expect(chat.hasAccess)
        #expect(chat.conversation(for: author).turns.count == 2)
        chat.endSession(id: second)
        chat.beginSession(id: UUID(), author: author)
        #expect(!chat.hasAccess)
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(await generator.requests.count == 8)
    }
    @Test func noCoinsMeansNoGeneration() async throws {
        let generator = ChatTestGenerator()
        let chat = ChatManager(generator: generator, progress: try await wallet(0))
        try await chat.prepare(); chat.beginSession(id: UUID(), author: author)
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(await generator.requests.isEmpty)
    }
    @Test func failedDebitDoesNotAppendOrSpendAndCanRetry() async throws {
        let repository = MemoryProgress()
        let progress = try await wallet(1, repository: repository)
        let chat = ChatManager(generator: ChatTestGenerator(), progress: progress)
        try await chat.prepare(); chat.beginSession(id: UUID(), author: author)
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(chat.coins == 1); #expect(!chat.sessionPaid)
        #expect(chat.conversation(for: author).turns.isEmpty)
        await repository.setFailure(false)
        try await chat.send("Hola", to: author, level: "A2")
        #expect(chat.coins == 0); #expect(chat.sessionPaid)
        let restored = ProgressManager(repository: repository); try await restored.load()
        #expect(restored.snapshot.doubloons == 0)
    }
    @Test(arguments: [true, false]) func interruptedGenerationDoesNotSpend(cancel: Bool) async throws {
        let generator = ChatTestGenerator(); await generator.configure(paused: true)
        let chat = ChatManager(generator: generator, progress: try await wallet(1))
        try await chat.prepare()
        let id = UUID(); chat.beginSession(id: id, author: author)
        let task = Task { try await chat.send("Hola", to: author, level: "A2") }
        while !(await generator.isWaiting()) { await Task.yield() }
        await #expect(throws: AppFailure.self) { try await chat.send("Otro", to: author, level: "A2") }
        if cancel { task.cancel() } else {
            chat.endSession(id: id)
            chat.beginSession(id: UUID(), author: author)
        }
        await generator.resume()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(chat.coins == 1); #expect(!chat.sessionPaid)
        #expect(chat.conversation(for: author).turns.isEmpty)
        #expect(!chat.busy)
    }
    @Test func newTopicRequiresNewCoinAndStaleCloseCannotEndNewSession() async throws {
        let chat = ChatManager(generator: ChatTestGenerator(), progress: try await wallet())
        try await chat.prepare()
        let oldID = UUID(); chat.beginSession(id: oldID, author: author)
        try await chat.send("Hola", to: author, level: "A2")
        try await chat.clear(author: author)
        #expect(!chat.sessionPaid)
        #expect(chat.conversation(for: author).turns.isEmpty)
        let id = UUID(); chat.beginSession(id: id, author: author)
        chat.endSession(id: oldID)
        try await chat.send("Nuevo tema", to: author, level: "A2")
        #expect(chat.coins == 0); #expect(chat.sessionPaid)
        chat.beginSession(id: id, author: author)
        #expect(chat.sessionPaid)
    }
    @Test func unavailableDeviceAndInvalidInputDoNotSpend() async throws {
        let generator = ChatTestGenerator()
        let chat = ChatManager(generator: generator, progress: try await wallet(1))
        try await chat.prepare(); chat.beginSession(id: UUID(), author: author)
        await #expect(throws: AppFailure.self) { try await chat.send(String(repeating: "a", count: 501), to: author, level: "A2") }
        await generator.configure(unavailable: "Model not ready")
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(chat.coins == 1); #expect(await generator.requests.isEmpty)
    }
    @Test(arguments: ["spanish-empty", "english-empty", "spanish-long", "english-long", "correction", "suggestion", "memory"])
    func invalidFirstReplyCostsNothing(field: String) async throws {
        let generator = ChatTestGenerator()
        var reply = ChatReply(spanish: "Hola", english: "Hello", correction: "", suggestion: "", memory: "Topic")
        switch field {
        case "spanish-empty": reply.spanish = " "
        case "english-empty": reply.english = " "
        case "spanish-long": reply.spanish = String(repeating: "a", count: 901)
        case "english-long": reply.english = String(repeating: "a", count: 901)
        case "correction": reply.correction = String(repeating: "a", count: 501)
        case "suggestion": reply.suggestion = String(repeating: "a", count: 251)
        default: reply.memory = String(repeating: "a", count: 701)
        }
        await generator.setReply(reply)
        let chat = ChatManager(generator: generator, progress: try await wallet(1))
        try await chat.prepare(); chat.beginSession(id: UUID(), author: author)
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(chat.coins == 1); #expect(!chat.sessionPaid)
        #expect(chat.conversation(for: author).turns.isEmpty)
    }
}
