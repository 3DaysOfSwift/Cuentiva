import Foundation
import Observation
import StoreKit

@MainActor protocol ChatFeature: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var displayPrice: String? { get }
    var preparing: Bool { get }
    var unavailable: String? { get }
    var ready: Bool { get }
    var busy: Bool { get }
    func prepare() async throws
    func purchase() async throws
    func restore() async throws
    func conversation(for author: Author) -> ChatConversation
    func send(_ message: String, to author: Author, level: String) async throws
    func clear(author: Author) async throws
}
@MainActor @Observable final class ChatManager: ChatFeature {
    private let purchases: any PurchaseFeature
    private let generator: any ChatGenerator
    private let repository: any ChatRepository
    private var conversations: [String: ChatConversation] = [:]
    private var loaded = false
    @ObservationIgnored private var preparationTask: Task<Void, Error>?
    private(set) var preparing = false
    private(set) var ready = false
    private(set) var busy = false
    private(set) var unavailable: String?
    var hasAccess: Bool { purchases.hasAccess }
    var displayPrice: String? { purchases.offer?.displayPrice }
    init(purchases: any PurchaseFeature, generator: any ChatGenerator, repository: any ChatRepository) {
        self.purchases = purchases; self.generator = generator; self.repository = repository
    }
    func prepare() async throws {
        // All callers await the same setup. Refreshes preserve an already loaded
        // conversation instead of replacing it with the loading screen.
        if let preparationTask { return try await preparationTask.value }
        preparing = true
        let task = Task { @MainActor in
            if !self.loaded {
                self.conversations = try await self.repository.load()
                self.loaded = true
            }
            self.unavailable = await self.generator.availabilityMessage()
            await self.purchases.refresh()
            self.ready = true
        }
        preparationTask = task
        defer { preparationTask = nil; preparing = false }
        try await task.value
    }
    func purchase() async throws {
        try await prepare()
        try Task.checkCancellation()
        if purchases.hasAccess { return }
        // Recheck immediately before the store sheet, even when called without UI.
        unavailable = await generator.availabilityMessage()
        if let unavailable { throw AppFailure.unavailable(unavailable) }
        try Task.checkCancellation()
        try await purchases.purchase()
    }
    func restore() async throws {
        // A device/model or local-file failure must never prevent restoration.
        try await purchases.restore()
    }
    func conversation(for author: Author) -> ChatConversation {
        guard purchases.hasAccess else { return .init() }
        return conversations[author.id] ?? .init()
    }
    func send(_ message: String, to author: Author, level: String) async throws {
        guard purchases.hasAccess else { throw AppFailure.unavailable("Unlock Storyteller Chat to start a conversation.") }
        guard loaded, ready else { throw AppFailure.unavailable("Please wait for chat to finish loading.") }
        guard !busy else { throw AppFailure.busy }
        let text = ChatLimits.normalizedMessage(message)
        guard ChatLimits.acceptsMessage(text) else { throw AppFailure.unavailable("Write a message of 1–500 characters.") }
        busy = true; defer { busy = false }
        unavailable = await generator.availabilityMessage()
        if let unavailable { throw AppFailure.unavailable(unavailable) }
        try Task.checkCancellation()
        guard purchases.hasAccess else { throw AppFailure.unavailable("Restore your chat purchase before continuing.") }
        let previous = conversations[author.id] ?? .init()
        // Retain the transcript locally, but keep each model request small. The
        // rolling summary preserves the topic without an ever-growing session.
        let reply = try await generator.reply(to: .init(name: String(author.storyteller.name.prefix(30)),
            biography: String(author.storyteller.introduction.prefix(400)),
            level: LearningLevel(rawValue: level) != nil ? level : "A2",
            memory: String(previous.memory.prefix(ChatLimits.memory)), recent: Array(previous.turns.suffix(ChatLimits.recentExchanges)), message: text))
        try Task.checkCancellation()
        guard purchases.hasAccess else { throw AppFailure.unavailable("Your chat purchase is no longer active. Restore purchases to check access.") }
        guard !reply.spanish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !reply.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              reply.spanish.count <= 900, reply.english.count <= 900,
              reply.correction.count <= 500, reply.suggestion.count <= 250, reply.memory.count <= 700 else {
            throw AppFailure.unavailable("The storyteller couldn’t finish a short reply. Please try again.")
        }
        var next = conversations
        var conversation = previous
        conversation.turns.append(.init(question: text, spanish: reply.spanish, english: reply.english,
                                        correction: reply.correction, suggestion: reply.suggestion))
        conversation.memory = String(reply.memory.prefix(ChatLimits.memory))
        next[author.id] = conversation
        // Save both halves together. A failed response or write never leaves a
        // dangling user message or consumes the draft in the composer.
        try await repository.save(next)
        conversations = next
    }
    func clear(author: Author) async throws {
        guard loaded, !busy else { throw AppFailure.busy }
        busy = true; defer { busy = false }
        var next = conversations
        next.removeValue(forKey: author.id)
        try await repository.save(next)
        conversations = next
    }
}
