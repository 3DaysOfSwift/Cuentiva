import Foundation
import Observation

@MainActor @Observable final class BookReaderViewModel {
    let audio: any LessonAudio
    private let learning: any LearningFeature
    private let pause: @Sendable () async throws -> Void
    private var playback: Task<Void, Never>?
    private var generation = UUID()
    private var nextIndex = 0
    private(set) var activeIndex: Int?
    private(set) var audioEnabled = true
    private(set) var busy = false
    private(set) var receipt: CompletionReceipt?
    var error: String?

    init(learning: any LearningFeature = AppModel.shared.learning, audio: (any LessonAudio)? = nil,
         pause: @escaping @Sendable () async throws -> Void = { try await Task.sleep(for: .seconds(1)) }) {
        self.learning = learning; self.audio = audio ?? AppModel.shared.makeAudio(); self.pause = pause
    }
    func start(_ book: Book) {
        guard audioEnabled, playback == nil, learning.canRead(book) else { return }
        let token = UUID(); generation = token
        playback = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == token { self.playback = nil; self.audio.stop(); self.activeIndex = nil; self.audioEnabled = false } }
            while self.nextIndex < book.fullText.count {
                guard !Task.isCancelled, self.generation == token, self.learning.canRead(book) else { return }
                let index = self.nextIndex
                self.activeIndex = index
                guard await self.audio.speakAndWait(book.fullText[index].spanish, slow: true),
                      !Task.isCancelled, self.generation == token else { return }
                self.nextIndex = index + 1
                if self.nextIndex < book.fullText.count,
                   (book.kind != .movieScript || book.fullText[index].speaker != book.fullText[self.nextIndex].speaker) {
                    do { try await self.pause() } catch { return }
                }
            }
            self.nextIndex = 0
        }
    }
    func toggleAudio(_ book: Book) {
        if audioEnabled { stop() }
        else { audioEnabled = true; start(book) }
    }
    func stop() {
        generation = UUID(); playback?.cancel(); playback = nil
        audio.stop(); activeIndex = nil; audioEnabled = false
    }
    func finish(_ book: Book) async {
        guard !busy else { return }
        busy = true; defer { busy = false }; error = nil; stop()
        do { receipt = try await learning.finishReading(book) }
        catch { self.error = error.localizedDescription }
    }
}
