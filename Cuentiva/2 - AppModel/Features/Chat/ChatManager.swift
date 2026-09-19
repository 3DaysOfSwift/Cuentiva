import Foundation
import Observation

@MainActor protocol ChatFeature: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var coins: Int { get }
    var sessionPaid: Bool { get }
    var preparing: Bool { get }
    var unavailable: String? { get }
    var ready: Bool { get }
    var busy: Bool { get }
    func beginSession(id: UUID, author: Author)
    func endSession(id: UUID)
    func prepare() async throws
    func conversation(for author: Author) -> ChatConversation
    func send(_ message: String, to author: Author, level: String) async throws
    func clear(author: Author) async throws
}

@MainActor @Observable final class ChatManager: ChatFeature {
    private let progress: any ProgressFeature
    private let generator: any ChatGenerator
    private var sessionID: UUID?
    private var sessionAuthorID: String?
    private var sessionConversation = ChatConversation()
    @ObservationIgnored private var preparationTask: Task<Void, Error>?
    private(set) var sessionPaid = false
    private(set) var preparing = false
    private(set) var ready = false
    private(set) var busy = false
    private(set) var unavailable: String?
    var coins: Int { progress.snapshot.availableChatCoins }
    var hasAccess: Bool { coins > 0 || sessionPaid }

    init(generator: any ChatGenerator, progress: any ProgressFeature) {
        self.progress = progress
        self.generator = generator
    }
    func beginSession(id: UUID, author: Author) {
        guard sessionID != id else { return }
        sessionID = id
        sessionAuthorID = author.id
        sessionPaid = false
        sessionConversation = .init()
    }
    func endSession(id: UUID) {
        guard sessionID == id else { return }
        sessionID = nil
        sessionAuthorID = nil
        sessionPaid = false
        sessionConversation = .init()
    }
    func prepare() async throws {
        if let preparationTask { return try await preparationTask.value }
        preparing = true
        let task = Task { @MainActor in
            try await self.progress.load()
            self.unavailable = await self.generator.availabilityMessage()
            self.ready = true
        }
        preparationTask = task
        defer { preparationTask = nil; preparing = false }
        try await task.value
    }
    func conversation(for author: Author) -> ChatConversation {
        sessionAuthorID == author.id ? sessionConversation : .init()
    }
    func send(_ message: String, to author: Author, level: String) async throws {
        guard hasAccess else {
            throw AppFailure.unavailable("Complete a story to earn a doubloon for a new chat.")
        }
        guard ready else { throw AppFailure.unavailable("Please wait for chat to finish loading.") }
        guard !busy else { throw AppFailure.busy }
        let text = ChatLimits.normalizedMessage(message)
        guard ChatLimits.acceptsMessage(text) else {
            throw AppFailure.unavailable("Write a message of 1–500 characters.")
        }
        guard let sendingSessionID = sessionID, sessionAuthorID == author.id else { throw CancellationError() }
        busy = true
        defer { busy = false }
        unavailable = await generator.availabilityMessage()
        if let unavailable { throw AppFailure.unavailable(unavailable) }
        try Task.checkCancellation()
        guard sessionID == sendingSessionID else { throw CancellationError() }
        let previous = sessionConversation
        let reply = try await generator.reply(to: makeRequest(message: text, author: author, level: level, conversation: previous))
        try Task.checkCancellation()
        guard sessionID == sendingSessionID else { throw CancellationError() }
        guard ChatLimits.acceptsReply(reply) else {
            throw AppFailure.unavailable("The storyteller couldn’t finish a short reply. Please try again.")
        }
        var conversation = previous
        conversation.turns.append(.init(question: text, spanish: reply.spanish, english: reply.english,
                                       correction: reply.correction, suggestion: reply.suggestion))
        conversation.memory = String(reply.memory.prefix(ChatLimits.memory))
        // Charge only after a valid first reply. Later messages never debit again.
        // Publish only after durable payment succeeds; AI failures cost nothing.
        if sessionPaid {
            sessionConversation = conversation
        } else {
            try await progress.payForChat {
                guard self.sessionID == sendingSessionID else { return false }
                self.sessionPaid = true
                self.sessionConversation = conversation
                return true
            }
        }
    }
    private func makeRequest(message: String, author: Author, level: String, conversation: ChatConversation) -> ChatRequest {
        let storyteller = author.storyteller
        return ChatRequest(
            name: String(storyteller.name.prefix(ChatLimits.authorName)),
            biography: String(storyteller.introduction.prefix(ChatLimits.biography)),
            level: (LearningLevel(rawValue: level) ?? .a2).rawValue,
            memory: String(conversation.memory.prefix(ChatLimits.memory)),
            recent: Array(conversation.turns.suffix(ChatLimits.recentExchanges)), message: message)
    }
    func clear(author: Author) async throws {
        guard ready, !busy else { throw AppFailure.busy }
        guard sessionAuthorID == author.id else { return }
        sessionPaid = false
        sessionConversation = .init()
    }
}
