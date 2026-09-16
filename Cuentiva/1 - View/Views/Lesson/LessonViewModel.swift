import Foundation
import Observation

@MainActor @Observable final class LessonViewModel {
    private let learning: any LearningFeature
    let audio: any LessonAudio
    private(set) var book: Book?
    private(set) var index = 0
    var mode = "Speak"
    var answer = ""
    var feedback: AnswerFeedback?
    var slow = false
    var showSpanish = false
    var error: String?
    var busy = false
    var receipt: CompletionReceipt?
    private var recordingTask: Task<Void, Never>?
    var sentence: Sentence? { guard let book else { return nil }; return book.sentences[index] }
    var practiced: Bool { guard let book, let sentence else { return false }; return learning.practiced(book, sentence: sentence) }
    var positionLabel: String { guard let book else { return "" }; return "\(index + 1) OF \(book.sentences.count) SENTENCES" }
    var fraction: Double { guard let book else { return 0 }; return Double(index + 1) / Double(book.sentences.count) }
    var nextTitle: String { guard let book else { return "Next" }; return index == book.sentences.count - 1 ? "Finish book" : "Next sentence" }
    var allowed: Bool { guard let book else { return false }; return learning.canRead(book) }
    init(learning: any LearningFeature = AppModel.shared.learning, audio: (any LessonAudio)? = nil) { self.learning = learning; self.audio = audio ?? AppModel.shared.makeAudio() }
    func load(_ book: Book) { guard self.book == nil else { return }; self.book = book; index = learning.position(book) }
    func listen() { guard allowed, let sentence else { return }; recordingTask?.cancel(); audio.speak(sentence.spanish, slow: slow) }
    func toggleRecording() {
        if audio.recording { audio.stopRecording() }
        else { guard allowed else { return }; recordingTask?.cancel(); recordingTask = Task { await audio.startRecording() } }
    }
    func changeMode() { stop(); feedback = nil; answer = ""; showSpanish = false }
    func stop() { recordingTask?.cancel(); recordingTask = nil; audio.stop() }
    func check() async {
        guard let book, let sentence, !busy else { return }
        busy = true; defer { busy = false }; error = nil
        let response = mode == "Speak" ? audio.transcript : answer
        audio.stopRecording()
        do { feedback = try await learning.check(book: book, sentence: sentence, answer: response) }
        catch { self.error = error.localizedDescription }
    }
    func next(skip: Bool = false) async {
        guard let book, !busy else { return }
        busy = true; defer { busy = false }; error = nil; stop()
        do {
            switch try await learning.advance(book: book, from: index, skip: skip) {
            case .position(let next, let revisiting):
                index = next
                if revisiting { error = "Let’s return to the sentences you skipped." }
            case .completed(let result): receipt = result; return
            }
            answer = ""; feedback = nil; showSpanish = false
        } catch { self.error = error.localizedDescription }
    }
    func back() async {
        guard let book, index > 0, !busy else { return }
        busy = true; defer { busy = false }; stop()
        do { try await learning.move(book: book, position: index - 1); index -= 1; answer = ""; feedback = nil; showSpanish = false }
        catch { self.error = error.localizedDescription }
    }
}
