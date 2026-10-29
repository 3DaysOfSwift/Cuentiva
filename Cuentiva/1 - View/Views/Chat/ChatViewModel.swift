//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class ChatViewModel {
    let author: Author
    let context: ConversationContext
    let feature: any ChatFeature
    private let audio: any LessonAudio
    private var spokenMessageID: UUID?
    var draft = ""
    var level: LearningLevel
    private(set) var preparationError: String?
    var error: String?
    var sending: Bool { !replyTasks.isEmpty }
    private var preparedSession = false
    var confirmingClear = false
    var translations: Set<UUID> = []
    var suggestionTranslations: Set<UUID> = []
    var suggestedTurn: ChatTurn? { turns.last { !$0.suggestion.isEmpty } }
    func toggleSuggestionTranslation(_ turn: ChatTurn) {
        if suggestionTranslations.contains(turn.id) { suggestionTranslations.remove(turn.id) }
        else { suggestionTranslations.insert(turn.id) }
    }
    private var sessionID = UUID()
    @ObservationIgnored private var preparationRequest: Task<Void, Never>?
    @ObservationIgnored private var preparationRequestID: UUID?
    @ObservationIgnored private var resetTask: Task<Void, Never>?
    private var replyTasks: [UUID: Task<Void, Never>] = [:]
    enum AdmissionPhase { case ready, accepted, celebrating, balanceUpdated, dismissing, finished }
    private(set) var admissionPhase: AdmissionPhase = .ready
    private(set) var admissionSuccess = 0
    private var admissionTask: Task<Void, Never>?
    private let admissionPause: @MainActor (Duration) async throws -> Void
    var admissionVisible: Bool { !feature.sessionAuthorized || (admissionPhase != .dismissing && admissionPhase != .finished) }
    var admissionCelebrating: Bool {
        admissionPhase == .celebrating || admissionPhase == .balanceUpdated
    }
    var displayedCoins: Int {
        let reserved = feature.sessionAuthorized && !feature.sessionPaid
            && admissionPhase != .ready && admissionPhase != .accepted && admissionPhase != .celebrating
        return max(0, feature.coins - (reserved ? feature.sessionCost : 0))
    }
    // Optimistic reservation only. The feature still commits the charge with the first reply.
    @discardableResult func celebrateAdmission() -> Bool {
        guard admissionPhase == .ready, authorizeSession() else { return false }
        admissionSuccess += 1
        admissionPhase = .accepted
        let admittingSession = sessionID
        admissionTask = Task {
            do {
                try await admissionPause(.milliseconds(80))
                guard !Task.isCancelled, sessionID == admittingSession else { return }
                admissionPhase = .celebrating
                try await admissionPause(.milliseconds(850))
                guard !Task.isCancelled, sessionID == admittingSession else { return }
                admissionPhase = .balanceUpdated
                try await admissionPause(.milliseconds(650))
                guard !Task.isCancelled, sessionID == admittingSession else { return }
                admissionPhase = .dismissing
                try await admissionPause(.milliseconds(450))
                guard !Task.isCancelled, sessionID == admittingSession else { return }
                admissionPhase = .finished
                admissionTask = nil
            } catch {
                // Ending a topic cancels the presentation and releases its reservation.
            }
        }
        return true
    }
    func resetAdmission() {
        admissionTask?.cancel()
        admissionTask = nil
        admissionPhase = .ready
    }
    init(author: Author, scenario: ConversationScenario? = nil, difficulty: RolePlayDifficulty = .easy,
         feature: any ChatFeature, audio: any LessonAudio, level: String = "A2",
         admissionPause: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.admissionPause = admissionPause
        self.author = author
        self.context = ConversationContext(author: author, scenario: scenario, difficulty: difficulty)
        self.feature = feature
        self.audio = audio
        self.level = LearningLevel(rawValue: level) ?? .a2
    }
    var unlocked: Bool { feature.hasAccess }
    var canPresentAdmission: Bool { preparedSession && feature.ready && feature.unavailable == nil }
    var canStart: Bool { unlocked && canPresentAdmission }
    @discardableResult func authorizeSession() -> Bool {
        guard canStart else { return false }
        error = nil
        do { try feature.authorizeSession(); return feature.sessionAuthorized }
        catch { self.error = error.localizedDescription; return false }
    }
    var sessionMessage: String {
        if feature.sessionPaid { return "This chat allowance is paid for. Return within ten minutes to continue." }
        if feature.sessionAuthorized { return "\(feature.sessionCost) doubloons reserved. Charged after your first successful reply." }
        return "\(feature.sessionCost) doubloons cover this chat. Charged after your first successful reply."
    }
    var turns: [ChatTurn] { feature.conversation(for: context).turns }
    var messages: [ChatMessage] { feature.conversation(for: context).messages }
    var metObjectives: Set<String> { feature.conversation(for: context).metObjectives }
    var scenarioComplete: Bool { feature.conversation(for: context).scenarioComplete }
    var composerNotice: String? {
        if let preparationError { return preparationError }
        if let unavailable = feature.unavailable { return unavailable }
        if let error { return error }
        if replyTasks.count >= 5 { return "Please wait for a reply before sending more messages." }
        return nil
    }
    var canSend: Bool {
        canStart && feature.sessionAuthorized && !scenarioComplete && replyTasks.count < 5
            && ChatLimits.acceptsMessage(draft)
    }
    @discardableResult func requestPreparation() -> Task<Void, Never> {
        if let preparationRequest { return preparationRequest }
        let requestID = UUID()
        let preparingSessionID = sessionID
        preparationRequestID = requestID
        let task = Task {
            defer {
                if preparationRequestID == requestID {
                    preparationRequest = nil
                    preparationRequestID = nil
                }
            }
            guard !Task.isCancelled, sessionID == preparingSessionID else { return }
            await prepare()
        }
        preparationRequest = task
        return task
    }
    func prepare() async {
        let preparingSessionID = sessionID
        preparationError = nil
        do {
            try await feature.prepare()
            guard !Task.isCancelled, sessionID == preparingSessionID else { return }
            feature.beginSession(id: preparingSessionID, context: context)
            preparedSession = true
            if feature.sessionPaid { admissionPhase = .finished }
        } catch {
            guard !Task.isCancelled, sessionID == preparingSessionID,
                  !(error is CancellationError) else { return }
            preparationError = error.localizedDescription
        }
    }
    func toggleTranslation(for turn: ChatMessage) {
        if !translations.insert(turn.id).inserted { translations.remove(turn.id) }
    }
    func send() {
        guard canSend else { return }
        let text = ChatLimits.normalizedMessage(draft)
        let sendingSession = sessionID
        let requestID = UUID()
        let sendingLevel = level.rawValue
        draft = ""
        error = nil
        replyTasks[requestID] = Task {
            defer { replyTasks[requestID] = nil }
            guard !Task.isCancelled, sessionID == sendingSession else { return }
            do {
                try await feature.send(text, in: context, level: sendingLevel)
                if sessionID == sendingSession, !feature.sessionAuthorized { resetAdmission() }
            } catch {
                guard sessionID == sendingSession else { return }
                if draft.isEmpty { draft = text }
                if !(error is CancellationError) { self.error = error.localizedDescription }
            }
        }
    }
    func cancel() {
        for task in replyTasks.values { task.cancel() }
        spokenMessageID = nil
        audio.stop()
    }
    func endSession() {
        preparationRequest?.cancel()
        preparationRequest = nil
        preparationRequestID = nil
        resetAdmission()
        cancel()
        feature.endSession(id: sessionID)
        sessionID = UUID()
        preparedSession = false
        draft = ""
        error = nil
        translations = []; suggestionTranslations = []
    }
    func listen(_ turn: ChatMessage) {
        guard unlocked else { return }
        spokenMessageID = turn.id
        audio.speak(turn.text, slow: true)
    }
    func spokenRange(for message: ChatMessage) -> NSRange? {
        guard unlocked, spokenMessageID == message.id else { return nil }
        return audio.spokenRange
    }
    var audioError: String? { audio.error }
    // Once dispatched, reset finishes saving even if this screen closes.
    // Repeated confirmation shares completion; session guards protect a later screen.
    @discardableResult func clear() -> Task<Void, Never> {
        if let resetTask { return resetTask }
        let clearingSessionID = sessionID
        let task = Task {
            defer { resetTask = nil }
            await clearSession(id: clearingSessionID)
        }
        resetTask = task
        return task
    }
    private func clearSession(id clearingSessionID: UUID) async {
        guard sessionID == clearingSessionID else { return }
        spokenMessageID = nil
        audio.stop()
        error = nil
        do {
            try await feature.clear(context: context)
            guard sessionID == clearingSessionID else { return }
            resetAdmission()
            translations = []; suggestionTranslations = []
        } catch {
            guard sessionID == clearingSessionID else { return }
            self.error = error.localizedDescription
        }
    }
}
