import Foundation
import Observation

@MainActor @Observable final class BookReaderViewModel {
    let audio: any LessonAudio
    private let learning: any LearningFeature
    private let pause: @Sendable () async throws -> Void
    private let wordPause: @Sendable (Duration) async throws -> Void
    private var playback: Task<Void, Never>?
    var isPlaying: Bool { playback != nil }
    var wordsPerMinute = 140.0
    private(set) var guideRange: NSRange?
    var highlightedRange: NSRange? { audioEnabled ? audio.spokenRange : guideRange }
    private var generation = UUID()
    private var nextIndex = 0
    private(set) var activeIndex: Int?
    private(set) var audioEnabled: Bool
    let chapterTwo: Bool
    var revealed: Set<String> = []
    func passages(_ book: Book) -> [Sentence] { chapterTwo ? (book.continuation ?? []) : book.fullText }
    private(set) var busy = false
    func chapterTitle(_ book: Book, at index: Int) -> String? {
        if chapterTwo { return index == 0 ? "Chapter 2" : nil }
        if index == 0 { return "Chapter 1" }
        if index == book.sentences.count { return "Chapter 2" }
        if index == book.chapterThreeStart { return "Chapter 3" }
        return nil
    }
    var error: String?

    init(chapterTwo: Bool = false, learning: any LearningFeature = AppModel.shared.learning, audio: (any LessonAudio)? = nil,
         pause: @escaping @Sendable () async throws -> Void = { try await Task.sleep(for: .seconds(1)) },
         wordPause: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.wordPause = wordPause
        self.chapterTwo = chapterTwo; self.audioEnabled = chapterTwo
        self.learning = learning; self.audio = audio ?? AppModel.shared.makeAudio(); self.pause = pause
    }
    func start(_ book: Book) {
        guard chapterTwo, audioEnabled, playback == nil, learning.canRead(book) else { return }
        let token = UUID(); generation = token
        playback = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == token { self.playback = nil; self.audio.stop(); self.activeIndex = nil; self.audioEnabled = false } }
            while self.nextIndex < self.passages(book).count {
                guard !Task.isCancelled, self.generation == token, self.learning.canRead(book) else { return }
                let index = self.nextIndex
                self.activeIndex = index
                guard await self.audio.speakAndWait(self.passages(book)[index].spanish, slow: true),
                      !Task.isCancelled, self.generation == token else { return }
                self.nextIndex = index + 1
                if self.nextIndex < self.passages(book).count,
                   (book.kind != .movieScript || self.passages(book)[index].speaker != self.passages(book)[self.nextIndex].speaker) {
                    do { try await self.pause() } catch { return }
                }
            }
            self.nextIndex = 0
        }
    }
    func toggleGuide(_ book: Book) {
        if isPlaying { stop() } else { startGuide(book) }
    }
    private func startGuide(_ book: Book) {
        guard !chapterTwo, playback == nil, learning.canRead(book) else { return }
        let token = UUID(); generation = token
        playback = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.generation == token {
                    self.playback = nil; self.audio.stop(); self.activeIndex = nil; self.guideRange = nil
                }
            }
            while self.nextIndex < self.passages(book).count {
                guard !Task.isCancelled, self.generation == token, self.learning.canRead(book) else { return }
                let index = self.nextIndex
                let text = self.passages(book)[index].spanish
                self.activeIndex = index
                if self.audioEnabled {
                    guard await self.audio.speakAndWait(text, slow: true) else { return }
                } else {
                    var ranges: [NSRange] = []
                    text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { _, range, _, _ in
                        ranges.append(NSRange(range, in: text))
                    }
                    for range in ranges {
                        guard !Task.isCancelled, self.generation == token, self.learning.canRead(book) else { return }
                        self.guideRange = range
                        do { try await self.wordPause(.seconds(60 / max(60, self.wordsPerMinute))) }
                        catch { return }
                    }
                }
                guard !Task.isCancelled, self.generation == token else { return }
                self.guideRange = nil
                self.nextIndex = index + 1
                if self.nextIndex < self.passages(book).count {
                    do { try await self.pause() } catch { return }
                }
            }
            self.nextIndex = 0
        }
    }
    func toggleAudio(_ book: Book) {
        if !chapterTwo {
            let wasPlaying = isPlaying
            stop()
            audioEnabled.toggle()
            if wasPlaying { startGuide(book) }
            return
        }
        if audioEnabled { stop() }
        else { audioEnabled = true; start(book) }
    }
    func stop() {
        generation = UUID(); playback?.cancel(); playback = nil
        audio.stop(); activeIndex = nil; guideRange = nil
        if chapterTwo { audioEnabled = false }
    }
    func finishChapter(_ book: Book) async -> Int? {
        guard !busy else { return nil }
        busy = true; defer { busy = false }; error = nil; stop()
        do { return try await learning.finishChapterTwo(book) }
        catch { self.error = error.localizedDescription; return nil }
    }
}
