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
    private func waitUntil(_ condition: () async -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while !(await condition()) {
            guard clock.now < deadline else { throw AppFailure.unavailable("Timed out waiting for chat test.") }
            await Task.yield()
        }
    }

    private func wallet(_ coins: Int = 2, repository: MemoryProgress = MemoryProgress()) async throws -> ProgressManager {
        var value = LearnerProgress(); value.doubloons = coins
        value.completed = Set((0..<11).map { "earned-\($0)" })
        try await repository.save(value)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        return progress
    }
    @Test func suggestedReplyTranslationSurvivesDeliveryAndLegacyDecoding() async throws {
        let generator = ChatTestGenerator()
        await generator.setReply(.init(spanish: "¿Dónde estás?", english: "Where are you?", correction: "",
            suggestion: "Estoy en casa.", memory: "Home", suggestionEnglish: "I am at home.", learnerEnglish: "Hello"))
        let chat = ChatManager(generator: generator, progress: try await wallet())
        try await chat.prepare()
        chat.beginSession(id: UUID(), author: author)
        try chat.authorizeSession()
        try await chat.send("Hola", to: author, level: "A1")
        let conversation = chat.conversation(for: author)
        #expect(conversation.messages.first?.role == .learner)
        #expect(conversation.messages.first?.english == "Hello")
        #expect(conversation.turns.first?.questionEnglish == "Hello")
        #expect(conversation.messages.last?.suggestionEnglish == "I am at home.")
        #expect(conversation.turns.last?.suggestionEnglish == "I am at home.")
        let data = try JSONEncoder().encode(conversation)
        let decoded = try JSONDecoder().decode(ChatConversation.self, from: data)
        #expect(decoded.turns.last?.suggestionEnglish == "I am at home.")
        #expect(decoded.messages.first?.english == "Hello")
        let projected = ChatConversation(turns: decoded.turns)
        #expect(projected.messages.first?.english == "Hello")
        var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var messages = try #require(legacy["messages"] as? [[String: Any]])
        for index in messages.indices { messages[index].removeValue(forKey: "suggestionEnglish") }
        legacy["messages"] = messages
        let oldData = try JSONSerialization.data(withJSONObject: legacy)
        let restored = try JSONDecoder().decode(ChatConversation.self, from: oldData)
        #expect(restored.turns.last?.suggestion == "Estoy en casa.")
        #expect(restored.turns.last?.suggestionEnglish == nil)
    }

    @Test func chatPromotionRequiresBothReadingMilestoneAndDeviceSupport() {
        var progress = LearnerProgress()
        progress.completed = Set((0..<11).map { "book-\($0)" })
        #expect(!progress.canOfferChat(onSupportedDevice: false))
        #expect(progress.canOfferChat(onSupportedDevice: true))
        let receipt = CompletionReceipt(book: sample(), isNew: true, total: 11)
        #expect(!receipt.offersChatGift(onSupportedDevice: false))
        #expect(receipt.offersChatGift(onSupportedDevice: true))
        progress.completed = []
        #expect(!progress.canOfferChat(onSupportedDevice: true))
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
    @Test func confirmingCostDoesNotSpendAndNewTopicsRequireFreshConsent() async throws {
        let generator = ChatTestGenerator()
        let chat = ChatManager(generator: generator, progress: try await wallet(2))
        try await chat.prepare()
        let id = UUID()
        chat.beginSession(id: id, author: author)
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A1") }
        #expect(await generator.requests.isEmpty)
        #expect(chat.conversation(for: author).messages.isEmpty)
        #expect(chat.coins == 2)
        try chat.authorizeSession()
        try chat.authorizeSession()
        #expect(chat.sessionAuthorized)
        #expect(!chat.sessionPaid)
        #expect(chat.coins == 2)
        chat.beginSession(id: id, author: author)
        #expect(chat.sessionAuthorized)
        try await chat.send("Hola", to: author, level: "A1")
        #expect(chat.coins == 1)
        try await chat.clear(author: author)
        #expect(!chat.sessionAuthorized)
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A1") }
        try chat.authorizeSession()
        chat.endSession(id: id)
        #expect(!chat.sessionAuthorized)
        #expect(chat.coins == 1)
    }

    @Test func unavailableAndEmptyWalletCannotAuthorizeChat() async throws {
        let generator = ChatTestGenerator()
        await generator.configure(unavailable: "Unsupported device")
        let unavailable = ChatManager(generator: generator, progress: try await wallet())
        try await unavailable.prepare()
        unavailable.beginSession(id: UUID(), author: author)
        #expect(throws: AppFailure.self) { try unavailable.authorizeSession() }
        #expect(!unavailable.sessionAuthorized)
        let empty = ChatManager(generator: ChatTestGenerator(), progress: try await wallet(0))
        try await empty.prepare()
        empty.beginSession(id: UUID(), author: author)
        #expect(throws: AppFailure.self) { try empty.authorizeSession() }
        #expect(!empty.sessionAuthorized)
    }

    @Test func oneCoinCoversContinuousChatAndClosingRequiresAnother() async throws {
        let progress = try await wallet()
        let generator = ChatTestGenerator()
        let chat = ChatManager(generator: generator, progress: progress)
        try await chat.prepare()
        let first = UUID(); chat.beginSession(id: first, author: author)
        if chat.hasAccess { try chat.authorizeSession() }
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
        if chat.hasAccess { try chat.authorizeSession() }
        try await chat.send("Otro tema", to: author, level: "A2")
        #expect(chat.coins == 0)
        try await chat.send("Más", to: author, level: "A2")
        #expect(chat.hasAccess)
        #expect(chat.conversation(for: author).turns.count == 2)
        chat.endSession(id: second)
        chat.beginSession(id: UUID(), author: author)
        if chat.hasAccess { try chat.authorizeSession() }
        #expect(!chat.hasAccess)
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(await generator.requests.count == 8)
    }
    @Test func outgoingBubblesAppearImmediatelyAndRepliesAreSerial() async throws {
        let progress = try await wallet(1)
        let generator = ChatTestGenerator()
        await generator.configure(paused: true)
        let chat = ChatManager(generator: generator, progress: progress)
        try await chat.prepare()
        chat.beginSession(id: UUID(), author: author)
        if chat.hasAccess { try chat.authorizeSession() }
        let first = Task { try await chat.send("Hola", to: author, level: "A2") }
        defer { first.cancel(); Task { await generator.resume() } }
        try await waitUntil { await generator.isWaiting() }
        let second = Task { try await chat.send("Soy de Londres", to: author, level: "A2") }
        defer { second.cancel() }
        try await waitUntil { chat.conversation(for: author).messages.count == 2 }
        #expect(chat.conversation(for: author).messages.map(\.role) == [.learner, .learner])
        #expect(await generator.requests.count == 1)
        #expect(chat.coins == 1)
        await generator.configure(paused: false)
        await generator.resume()
        try await first.value
        try await second.value
        let transcript = chat.conversation(for: author).messages
        #expect(transcript.map(\.role) == [.learner, .learner, .storyteller, .storyteller])
        #expect(transcript.allSatisfy { $0.delivery == .delivered })
        #expect(chat.coins == 0)
        #expect(await generator.requests.count == 2)
        #expect(!chat.busy)
    }

    @Test func storytellerCanSendSeveralBubblesForOneCoin() async throws {
        let generator = ChatTestGenerator()
        await generator.setReply(.init(spanish: "¡Hola!", english: "Hello!", correction: "", suggestion: "", memory: "Greetings",
            additionalMessages: [.init(spanish: "¿Cómo estás?", english: "How are you?")]))
        let chat = ChatManager(generator: generator, progress: try await wallet(1))
        try await chat.prepare()
        chat.beginSession(id: UUID(), author: author)
        if chat.hasAccess { try chat.authorizeSession() }
        try await chat.send("Hola", to: author, level: "A1")
        #expect(chat.conversation(for: author).messages.map(\.role) == [.learner, .storyteller, .storyteller])
        #expect(chat.coins == 0)
    }

    @Test func noCoinsMeansNoGeneration() async throws {
        let generator = ChatTestGenerator()
        let chat = ChatManager(generator: generator, progress: try await wallet(0))
        try await chat.prepare(); chat.beginSession(id: UUID(), author: author)
        if chat.hasAccess { try chat.authorizeSession() }
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(await generator.requests.isEmpty)
    }
    @Test func failedDebitDoesNotAppendOrSpendAndCanRetry() async throws {
        let repository = MemoryProgress()
        let progress = try await wallet(1, repository: repository)
        let chat = ChatManager(generator: ChatTestGenerator(), progress: progress)
        try await chat.prepare(); chat.beginSession(id: UUID(), author: author)
        if chat.hasAccess { try chat.authorizeSession() }
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
        if chat.hasAccess { try chat.authorizeSession() }
        let task = Task { try await chat.send("Hola", to: author, level: "A2") }
        while !(await generator.isWaiting()) { await Task.yield() }
        if cancel { task.cancel() } else {
            chat.endSession(id: id)
            chat.beginSession(id: UUID(), author: author)
            if chat.hasAccess { try chat.authorizeSession() }
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
        if chat.hasAccess { try chat.authorizeSession() }
        try await chat.send("Hola", to: author, level: "A2")
        try await chat.clear(author: author)
        #expect(!chat.sessionPaid)
        #expect(chat.conversation(for: author).turns.isEmpty)
        let id = UUID(); chat.beginSession(id: id, author: author)
        if chat.hasAccess { try chat.authorizeSession() }
        chat.endSession(id: oldID)
        try await chat.send("Nuevo tema", to: author, level: "A2")
        #expect(chat.coins == 0); #expect(chat.sessionPaid)
        chat.beginSession(id: id, author: author)
        if chat.hasAccess { try chat.authorizeSession() }
        #expect(chat.sessionPaid)
    }
    @Test func unavailableDeviceAndInvalidInputDoNotSpend() async throws {
        let generator = ChatTestGenerator()
        let chat = ChatManager(generator: generator, progress: try await wallet(1))
        try await chat.prepare(); chat.beginSession(id: UUID(), author: author)
        if chat.hasAccess { try chat.authorizeSession() }
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
        if chat.hasAccess { try chat.authorizeSession() }
        await #expect(throws: AppFailure.self) { try await chat.send("Hola", to: author, level: "A2") }
        #expect(chat.coins == 1); #expect(!chat.sessionPaid)
        #expect(chat.conversation(for: author).turns.isEmpty)
    }
}
