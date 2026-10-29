//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor protocol ChatFeature: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var coins: Int { get }
    var sessionPaid: Bool { get }
    var sessionAuthorized: Bool { get }
    var sessionCost: Int { get }
    func authorizeSession() throws
    var preparing: Bool { get }
    var unavailable: String? { get }
    var ready: Bool { get }
    var busy: Bool { get }
    func beginSession(id: UUID, author: Author)
    func beginSession(id: UUID, context: ConversationContext)
    func endSession(id: UUID)
    func prepare() async throws
    func conversation(for author: Author) -> ChatConversation
    func conversation(for context: ConversationContext) -> ChatConversation
    func send(_ message: String, to author: Author, level: String) async throws
    func send(_ message: String, in context: ConversationContext, level: String) async throws
    func clear(author: Author) async throws
    func clear(context: ConversationContext) async throws
}

extension ChatFeature {
    func beginSession(id: UUID, context: ConversationContext) { beginSession(id: id, author: context.author) }
    func conversation(for context: ConversationContext) -> ChatConversation { conversation(for: context.author) }
    func send(_ message: String, in context: ConversationContext, level: String) async throws {
        try await send(message, to: context.author, level: level)
    }
    func clear(context: ConversationContext) async throws { try await clear(author: context.author) }
}

@MainActor @Observable final class ChatManager: ChatFeature {
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    private var sessionScenario: ConversationScenario?
    private let generator: any ChatGenerator
    private let now: () -> Date
    private var savedReceiptID: UUID?
    private var sentInAllowance = 0
    @ObservationIgnored private var checkpointTask: Task<Void, Error>?
    private var resetInProgress = false
    private var sessionID: UUID?
    private var sessionStorageKey: String?
    private(set) var sessionCost = 1
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
    var hasAccess: Bool { purchases.hasAccess && !purchases.checking && progress.snapshot.chatUnlocked && (coins >= sessionCost || sessionPaid) }

    init(generator: any ChatGenerator, progress: any ProgressFeature, purchases: any PurchaseFeature, now: @escaping () -> Date = Date.init) {
        self.purchases = purchases
        self.now = now
        self.progress = progress
        self.generator = generator
    }
    func beginSession(id: UUID, author: Author) {
        beginSession(id: id, context: ConversationContext(author: author))
    }
    func beginSession(id: UUID, context: ConversationContext) {
        guard sessionID != id else { return }
        sessionID = id
        sessionScenario = context.scenario
        sessionStorageKey = context.storageKey
        sessionCost = context.isRolePlay ? 2 : 1
        let saved = progress.snapshot.chatSessions?[context.storageKey]
        savedReceiptID = saved?.receiptID
        sentInAllowance = saved?.sentMessages ?? 0
        sessionPaid = saved?.canResume(at: now()) == true
        sessionAuthorized = sessionPaid
        sessionConversation = saved?.conversation ?? .init()
    }
    func endSession(id: UUID) {
        guard sessionID == id else { return }
        if sessionPaid, let storageKey = sessionStorageKey, let receiptID = savedReceiptID {
            let earlier = checkpointTask
            checkpointTask = Task {
                if let earlier { try await earlier.value }
                try await progress.checkpointChat(authorID: storageKey, receiptID: receiptID)
            }
        }
        sessionID = nil
        sessionStorageKey = nil
        sessionCost = 1
        savedReceiptID = nil
        sentInAllowance = 0
        sessionPaid = false
        sessionAuthorized = false
        sessionConversation = .init()
    }
    private func validateSessionAccess() throws {
        guard progress.snapshot.chatUnlocked else {
            throw AppFailure.unavailable("Storyteller Chat unlocks after you complete \(ReadingMilestones.chatOfferBookCount) books.")
        }
        guard purchases.hasAccess, !purchases.checking else {
            throw AppFailure.unavailable("An active subscription is needed to chat.")
        }
        if let scenario = sessionScenario, !progress.snapshot.canStartRolePlay(scenario) {
            throw AppFailure.unavailable("Complete the previous Role Play before starting this one.")
        }
        guard !sessionConversation.scenarioComplete else {
            throw AppFailure.unavailable("This Role Play has ended. Reset it to practise again.")
        }
    }
    func authorizeSession() throws {
        try validateSessionAccess()
        guard ready, sessionID != nil else { throw AppFailure.unavailable("Please wait for chat to finish loading.") }
        if let unavailable { throw AppFailure.unavailable(unavailable) }
        guard hasAccess else { throw AppFailure.unavailable("You need \(sessionCost) doubloons to begin this conversation.") }
        sessionAuthorized = true
    }
    func prepare() async throws {
        if let preparationTask { return try await preparationTask.value }
        preparing = true
        let task = Task { @MainActor in
            try await self.progress.load()
            if let checkpoint = self.checkpointTask {
                self.checkpointTask = nil
                try await checkpoint.value
            }
            self.unavailable = await self.generator.availabilityMessage()
            self.ready = true
        }
        preparationTask = task
        defer { preparationTask = nil; preparing = false }
        try await task.value
    }
    func conversation(for author: Author) -> ChatConversation {
        conversation(for: ConversationContext(author: author))
    }
    func conversation(for context: ConversationContext) -> ChatConversation {
        sessionStorageKey == context.storageKey ? sessionConversation : .init()
    }
    func send(_ message: String, to author: Author, level: String) async throws {
        try await send(message, in: ConversationContext(author: author), level: level)
    }
    func send(_ message: String, in context: ConversationContext, level: String) async throws {
        guard !resetInProgress else { throw AppFailure.busy }
        try validateSessionAccess()
        guard hasAccess else {
            throw AppFailure.unavailable("Complete a story to earn a doubloon for a new chat.")
        }
        guard ready else { throw AppFailure.unavailable("Please wait for chat to finish loading.") }
        let text = ChatLimits.normalizedMessage(message)
        guard ChatLimits.acceptsMessage(text) else {
            throw AppFailure.unavailable("Write a message of 1–500 characters.")
        }
        guard let sendingSessionID = sessionID, sessionStorageKey == context.storageKey else { throw CancellationError() }
        guard sessionConversation.messages.filter({ $0.delivery == .pending }).count < 5 else {
            throw AppFailure.unavailable("Please wait for a reply before sending more messages.")
        }
        if let unavailable { throw AppFailure.unavailable(unavailable) }
        guard sessionAuthorized else { throw AppFailure.unavailable("Confirm the \(sessionCost)-doubloon cost before starting your chat.") }
        let pending = sessionConversation.messages.filter { $0.role == .learner && $0.delivery == .pending }.count
        let used = sessionPaid ? sentInAllowance : 0
        guard used + pending < ChatLimits.messagesPerCoin else {
            throw AppFailure.unavailable("Please wait for the final reply before continuing for another doubloon.")
        }
        let outgoing = ChatMessage(role: .learner, text: text, delivery: .pending)
        sessionConversation.messages.append(outgoing)
        // Publish the learner's bubble immediately, then process replies in order.
        await acquireReply()
        defer { releaseReply() }
        do {
            try Task.checkCancellation()
            guard sessionID == sendingSessionID else { throw CancellationError() }
            try validateSessionAccess()
            unavailable = await generator.availabilityMessage()
            if let unavailable { throw AppFailure.unavailable(unavailable) }
            try Task.checkCancellation()
            guard sessionID == sendingSessionID else { throw CancellationError() }
            try validateSessionAccess()
            let reply = try await generator.reply(to: makeRequest(message: text, context: context,
                level: level, conversation: sessionConversation))
            try Task.checkCancellation()
            guard sessionID == sendingSessionID else { throw CancellationError() }
            try validateSessionAccess()
            guard ChatLimits.acceptsReply(reply) else {
                throw AppFailure.unavailable("The storyteller couldn’t finish a short reply. Please try again.")
            }
            var updated = sessionConversation
            if let index = updated.messages.firstIndex(where: { $0.id == outgoing.id }) {
                updated.messages[index].delivery = .delivered
                updated.messages[index].english = reply.learnerEnglish ?? ""
            }
            let allowedObjectives = Set(context.scenario?.requiredObjectives ?? [])
            let metObjectives = reply.metObjectives.filter(allowedObjectives.contains)
            let replyStillAsksForInformation = ([reply.spanish] + reply.additionalMessages.map(\.spanish))
                .contains { $0.contains("?") || $0.contains("¿") }
            let scenarioComplete = context.scenario != nil && reply.scenarioComplete
                && allowedObjectives.isSubset(of: Set(updated.metObjectives).union(metObjectives))
                && !replyStillAsksForInformation
            updated.messages.append(ChatMessage(role: .storyteller, text: reply.spanish,
                inReplyTo: outgoing.id, english: reply.english, correction: reply.correction,
                suggestion: reply.suggestion, suggestionEnglish: reply.suggestionEnglish,
                metObjectives: metObjectives, scenarioComplete: scenarioComplete))
            for message in reply.additionalMessages {
                updated.messages.append(ChatMessage(role: .storyteller, text: message.spanish,
                    inReplyTo: outgoing.id, english: message.english))
            }
            updated.memory = String(reply.memory.prefix(ChatLimits.memory))
            let saved = try await progress.saveChatReply(authorID: context.storageKey, conversation: updated,
                receiptID: savedReceiptID, renewing: !sessionPaid, cost: sessionCost)
            // The save committed payment and transcript. Publish that confirmed result
            // even if access changed during persistence; subsequent sends recheck access.
            guard sessionID == sendingSessionID else { throw CancellationError() }
            savedReceiptID = saved.receiptID
            sentInAllowance = saved.sentMessages
            // Preserve any new outgoing messages appended while the save was suspended.
            let existingIDs = Set(updated.messages.map(\.id))
            updated.messages.append(contentsOf: sessionConversation.messages.filter { !existingIDs.contains($0.id) })
            sessionConversation = updated
            sessionPaid = sentInAllowance < ChatLimits.messagesPerCoin
            sessionAuthorized = sessionPaid

        } catch {
            if sessionID == sendingSessionID,
               let index = sessionConversation.messages.firstIndex(where: { $0.id == outgoing.id }),
               sessionConversation.messages[index].delivery == .pending {
                sessionConversation.messages[index].delivery = .failed
            }
            throw error
        }
    }
    private func makeRequest(message: String, context: ConversationContext, level: String, conversation: ChatConversation) -> ChatRequest {
        let storyteller = context.author.storyteller
        return ChatRequest(
            name: String(storyteller.name.prefix(ChatLimits.authorName)),
            biography: String(storyteller.introduction.prefix(ChatLimits.biography)),
            persona: .forAuthorID(storyteller.id),
            level: (LearningLevel(rawValue: level) ?? .a2).rawValue,
            memory: String(conversation.memory.prefix(ChatLimits.memory)),
            recent: Array(conversation.turns.suffix(ChatLimits.recentExchanges)), message: message,
            scenario: context.scenario, difficulty: context.difficulty)
    }
    func clear(author: Author) async throws {
        try await clear(context: ConversationContext(author: author))
    }
    func clear(context: ConversationContext) async throws {
        guard ready, !busy, !resetInProgress else { throw AppFailure.busy }
        guard sessionStorageKey == context.storageKey, let clearingSessionID = sessionID else { return }
        resetInProgress = true
        defer { resetInProgress = false }
        try await progress.clearChat(authorID: context.storageKey)
        guard sessionID == clearingSessionID else { return }
        savedReceiptID = nil
        sentInAllowance = 0
        sessionPaid = false
        sessionAuthorized = false
        sessionConversation = .init()
    }
}
