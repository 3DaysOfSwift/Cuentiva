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
    var notice: String?
    var sending = false
    var confirmingClear = false
    var translations: Set<UUID> = []
    private var sessionID = UUID()
    private var replyTask: Task<Void, Never>?
    init(author: Author, feature: any ChatFeature, audio: any LessonAudio, level: String = "A2") {
        self.author = author
        self.feature = feature
        self.audio = audio
        self.level = LearningLevel(rawValue: level) ?? .a2
    }
    var unlocked: Bool { feature.hasAccess }
    var sessionMessage: String {
        if feature.sessionPaid { return "This topic is paid for. Keep chatting while this screen stays open." }
        return "1 doubloon starts one topic. Closing this screen ends the session. You have \(feature.coins) doubloons."
    }
    var turns: [ChatTurn] { feature.conversation(for: author).turns }
    var canSend: Bool {
        unlocked && feature.ready && feature.unavailable == nil && !feature.busy && !sending
            && ChatLimits.acceptsMessage(draft)
    }
    func prepare() async {
        let preparingSessionID = sessionID
        preparationError = nil
        do {
            try await feature.prepare()
            guard !Task.isCancelled, sessionID == preparingSessionID else { return }
            feature.beginSession(id: preparingSessionID, author: author)
        } catch { preparationError = error.localizedDescription }
    }
    func toggleTranslation(for turn: ChatTurn) {
        if !translations.insert(turn.id).inserted { translations.remove(turn.id) }
    }
    func send() {
        guard canSend else { return }
        let text = draft
        sending = true
        error = nil
        notice = nil
        replyTask = Task {
            defer {
                sending = false
                replyTask = nil
            }
            do {
                try await feature.send(text, to: author, level: level.rawValue)
                if draft == text { draft = "" }
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
    func cancel() {
        replyTask?.cancel()
        audio.stop()
    }
    func endSession() {
        cancel()
        feature.endSession(id: sessionID)
        sessionID = UUID()
        translations = []
    }
    func listen(_ turn: ChatTurn) { if unlocked { audio.speak(turn.spanish, slow: false) } }
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
