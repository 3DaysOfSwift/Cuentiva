import Foundation
import Observation

@MainActor @Observable final class ChatViewModel {
    let author: Author
    let feature: any ChatFeature
    private let audio: any LessonAudio
    var draft = ""
    var level: LearningLevel
    private(set) var preparationError: String?
    var error: String?
    var sending: Bool { !replyTasks.isEmpty }
    private var preparedSession = false
    var confirmingClear = false
    var translations: Set<UUID> = []
    private var sessionID = UUID()
    private var replyTasks: [UUID: Task<Void, Never>] = [:]
    init(author: Author, feature: any ChatFeature, audio: any LessonAudio, level: String = "A2") {
        self.author = author
        self.feature = feature
        self.audio = audio
        self.level = LearningLevel(rawValue: level) ?? .a2
    }
    var unlocked: Bool { feature.hasAccess }
    var canStart: Bool { unlocked && preparedSession && feature.ready && feature.unavailable == nil }
    func authorizeSession() {
        guard canStart else { return }
        error = nil
        do { try feature.authorizeSession() }
        catch { self.error = error.localizedDescription }
    }
    var sessionMessage: String {
        if feature.sessionPaid { return "This topic is paid for. Keep chatting while this screen stays open." }
        return "One doubloon covers this topic. Charged after your first successful reply."
    }
    var turns: [ChatTurn] { feature.conversation(for: author).turns }
    var messages: [ChatMessage] { feature.conversation(for: author).messages }
    var composerNotice: String? {
        if let preparationError { return preparationError }
        if let unavailable = feature.unavailable { return unavailable }
        if let error { return error }
        if replyTasks.count >= 5 { return "Please wait for a reply before sending more messages." }
        return nil
    }
    var canSend: Bool {
        canStart && feature.sessionAuthorized && replyTasks.count < 5
            && ChatLimits.acceptsMessage(draft)
    }
    func prepare() async {
        let preparingSessionID = sessionID
        preparationError = nil
        do {
            try await feature.prepare()
            guard !Task.isCancelled, sessionID == preparingSessionID else { return }
            feature.beginSession(id: preparingSessionID, author: author)
            preparedSession = true
        } catch { preparationError = error.localizedDescription }
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
            do {
                try await feature.send(text, to: author, level: sendingLevel)
            } catch {
                guard sessionID == sendingSession else { return }
                if draft.isEmpty { draft = text }
                if !(error is CancellationError) { self.error = error.localizedDescription }
            }
        }
    }
    func cancel() {
        for task in replyTasks.values { task.cancel() }
        audio.stop()
    }
    func endSession() {
        cancel()
        feature.endSession(id: sessionID)
        sessionID = UUID()
        preparedSession = false
        draft = ""
        error = nil
        translations = []
    }
    func listen(_ turn: ChatMessage) { if unlocked { audio.speak(turn.text, slow: false) } }
    var audioError: String? { audio.error }
    func clear() async {
        audio.stop()
        error = nil
        do {
            try await feature.clear(author: author)
            translations = []
        } catch { self.error = error.localizedDescription }
    }
}
