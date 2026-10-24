//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class LessonViewModel {
    private let learning: any LearningFeature
    let audio: any LessonAudio
    private(set) var book: Book?
    private(set) var index = 0
    var mode = "Speak"
    var role = ""
    var isPartnerLine: Bool { !role.isEmpty && sentence?.speaker != role }
    private var writingDrafts: [String: String] = [:]
    var answer = "" {
        didSet { if let sentence { writingDrafts[sentence.id] = answer } }
    }
    var feedback: AnswerFeedback?
    var slow = false
    var showSpanish = false
    var error: String?
    var busy = false
    private(set) var showingReader = false
    private(set) var receipt: CompletionReceipt?
    var showingWholeBook = false
    var showingCompletion = false
    var chapter: Int { guard let book else { return 1 }; return index >= book.chapterThreeStart ? 3 : 1 }
    private(set) var showingChapterCelebration = false
    private var recordingTask: Task<Void, Never>?
    var sentence: Sentence? {
        guard let book, book.fullText.indices.contains(index) else { return nil }
        return book.fullText[index]
    }
    var positionLabel: String {
        guard let book else { return "" }
        let start = chapter == 3 ? book.chapterThreeStart : 0
        let count = chapter == 3 ? (book.ending ?? []).count : book.sentences.count
        return "CHAPTER \(chapter) · \(index - start + 1) OF \(count) \(book.unitName.uppercased())"
    }
    var fraction: Double {
        guard let book else { return 0 }
        let start = chapter == 3 ? book.chapterThreeStart : 0
        let count = chapter == 3 ? (book.ending ?? []).count : book.sentences.count
        return Double(index - start + 1) / Double(max(1, count))
    }
    var nextTitle: String {
        guard let book else { return "Next" }
        if index == book.fullText.count - 1 { return "Complete chapter \(chapter)" }
        return index == book.sentences.count - 1
            ? "Complete chapter 1"
            : (book.kind == .movieScript ? "Next line" : "Next sentence")
    }
    var allowed: Bool {
        guard let book else { return false }
        return learning.canRead(book)
    }
    init(learning: any LearningFeature = AppModel.shared.learning, audio: (any LessonAudio)? = nil) {
        self.learning = learning
        self.audio = audio ?? AppModel.shared.makeAudio()
    }
    func load(_ book: Book) {
        guard self.book == nil else { return }
        self.book = book
        index = learning.position(book)
        showingReader = index >= book.sentences.count && index < book.chapterThreeStart
    }
    func listen() {
        guard allowed, let sentence else { return }
        recordingTask?.cancel()
        audio.speak(sentence.spanish, slow: slow)
    }
    func toggleRecording() {
        if audio.recording {
            audio.stopRecording()
        } else {
            guard allowed else { return }
            recordingTask?.cancel()
            recordingTask = Task { await audio.startRecording() }
        }
    }
    func changeMode() {
        stop()
        feedback = nil
        showSpanish = false
        error = nil
    }
    func stop() {
        recordingTask?.cancel()
        recordingTask = nil
        audio.stop()
    }
    func check() async {
        guard let book, let sentence, !busy else { return }
        busy = true
        defer { busy = false }
        error = nil
        let response = mode == "Speak" ? audio.transcript : answer
        audio.stopRecording()
        do { feedback = try await learning.check(book: book, sentence: sentence, answer: response) } catch {
            self.error = error.localizedDescription
        }
    }
    func next() async {
        guard let book, !busy else { return }
        busy = true
        defer { busy = false }
        error = nil
        stop()
        do {
            switch try await learning.advance(book: book, from: index) {
            case .bookFinished:
                receipt = try await learning.finish(book)
                return
            case .position(let next): index = next
            case .fullReading:
                showingChapterCelebration = true
                return
            }
            answer = sentence.flatMap { writingDrafts[$0.id] } ?? ""
            feedback = nil
            showSpanish = false
        } catch { self.error = error.localizedDescription }
    }
    func readMoreFluently() {
        guard showingChapterCelebration, allowed else { return }
        showingChapterCelebration = false
        showingReader = true
    }

    func chapterTwoFinished(at position: Int) async {
        guard let book else { return }
        index = position
        feedback = nil; answer = ""; showSpanish = false; error = nil
        showingReader = false
        if position >= book.fullText.count {
            do { receipt = try await learning.finish(book) }
            catch { self.error = error.localizedDescription; showingReader = true }
        }
    }

    func back() async {
        guard let book, index > (chapter == 3 ? book.chapterThreeStart : 0), !busy else { return }
        busy = true
        defer { busy = false }
        stop()
        do {
            try await learning.move(book: book, position: index - 1)
            index -= 1
            answer = sentence.flatMap { writingDrafts[$0.id] } ?? ""
            feedback = nil
            showSpanish = false
        } catch { self.error = error.localizedDescription }
    }
}
