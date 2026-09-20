import Foundation
import Observation

@MainActor protocol ChatFeature: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var coins: Int { get }
    var sessionPaid: Bool { get }
    var sessionAuthorized: Bool { get }
    func authorizeSession() throws
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
    private(set) var sessionAuthorized = false
    private(set) var preparing = false
    private(set) var ready = false
    private(set) var busy = false
    @ObservationIgnored private var waitingReplies: [CheckedContinuation<Void, Never>] = []
    private func acquireReply() async {
        if !busy { busy = true; return }
        await withCheckedContinuation { waitingReplies.append($0) }
    }
    private func releaseReply() {
        if waitingReplies.isEmpty { busy = false }
        else { waitingReplies.removeFirst().resume() }
    }
    private(set) var unavailable: String?
    var coins: Int { progress.snapshot.availableChatCoins }
    var hasAccess: Bool { progress.snapshot.chatUnlocked && (coins > 0 || sessionPaid) }

    init(generator: any ChatGenerator, progress: any ProgressFeature) {
        self.progress = progress
        self.generator = generator
    }
    func beginSession(id: UUID, author: Author) {
        guard sessionID != id else { return }
        sessionID = id
        sessionAuthorID = author.id
        sessionPaid = false
        sessionAuthorized = false
        sessionConversation = .init()
    }
    func endSession(id: UUID) {
        guard sessionID == id else { return }
        sessionID = nil
        sessionAuthorID = nil
        sessionPaid = false
        sessionAuthorized = false
        sessionConversation = .init()
    }
    func authorizeSession() throws {
        guard ready, sessionID != nil else { throw AppFailure.unavailable("Please wait for chat to finish loading.") }
        if let unavailable { throw AppFailure.unavailable(unavailable) }
        guard hasAccess else { throw AppFailure.unavailable("Complete a story to earn a doubloon for a new chat.") }
        sessionAuthorized = true
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
        guard progress.snapshot.chatUnlocked else {
            throw AppFailure.unavailable("Storyteller Chat unlocks after you complete 11 books.")
        }
        guard hasAccess else {
            throw AppFailure.unavailable("Complete a story to earn a doubloon for a new chat.")
        }
        guard ready else { throw AppFailure.unavailable("Please wait for chat to finish loading.") }
        let text = ChatLimits.normalizedMessage(message)
        guard ChatLimits.acceptsMessage(text) else {
            throw AppFailure.unavailable("Write a message of 1–500 characters.")
        }
        guard let sendingSessionID = sessionID, sessionAuthorID == author.id else { throw CancellationError() }
        guard sessionConversation.messages.filter({ $0.delivery == .pending }).count < 5 else {
            throw AppFailure.unavailable("Please wait for a reply before sending more messages.")
        }
        if let unavailable { throw AppFailure.unavailable(unavailable) }
        guard sessionAuthorized else { throw AppFailure.unavailable("Confirm the 1 doubloon cost before starting your chat.") }
        let outgoing = ChatMessage(role: .learner, text: text, delivery: .pending)
        sessionConversation.messages.append(outgoing)
        // Publish the learner's bubble immediately, then process replies in order.
        await acquireReply()
        defer { releaseReply() }
        do {
            try Task.checkCancellation()
            guard sessionID == sendingSessionID else { throw CancellationError() }
            unavailable = await generator.availabilityMessage()
            if let unavailable { throw AppFailure.unavailable(unavailable) }
            try Task.checkCancellation()
            guard sessionID == sendingSessionID else { throw CancellationError() }
            let reply = try await generator.reply(to: makeRequest(message: text, author: author,
                level: level, conversation: sessionConversation))
            try Task.checkCancellation()
            guard sessionID == sendingSessionID else { throw CancellationError() }
            guard ChatLimits.acceptsReply(reply) else {
                throw AppFailure.unavailable("The storyteller couldn’t finish a short reply. Please try again.")
            }
            let deliver: @MainActor @Sendable () -> Bool = {
                guard self.sessionID == sendingSessionID else { return false }
                self.sessionPaid = true
                if let index = self.sessionConversation.messages.firstIndex(where: { $0.id == outgoing.id }) {
                    self.sessionConversation.messages[index].delivery = .delivered
                }
                self.sessionConversation.messages.append(ChatMessage(role: .storyteller, text: reply.spanish,
                    inReplyTo: outgoing.id, english: reply.english, correction: reply.correction, suggestion: reply.suggestion))
                for message in reply.additionalMessages {
                    self.sessionConversation.messages.append(ChatMessage(role: .storyteller, text: message.spanish,
                        inReplyTo: outgoing.id, english: message.english))
                }
                self.sessionConversation.memory = String(reply.memory.prefix(ChatLimits.memory))
                return true
            }
            if sessionPaid { _ = deliver() }
            else { try await progress.payForChat(deliver: deliver) }
        } catch {
            if sessionID == sendingSessionID,
               let index = sessionConversation.messages.firstIndex(where: { $0.id == outgoing.id }),
               sessionConversation.messages[index].delivery == .pending {
                sessionConversation.messages[index].delivery = .failed
            }
            throw error
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
        sessionAuthorized = false
        sessionConversation = .init()
    }
}
