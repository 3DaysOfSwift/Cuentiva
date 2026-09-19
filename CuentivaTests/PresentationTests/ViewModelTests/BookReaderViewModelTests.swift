import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct BookReaderViewModelTests {
    @Test(arguments: [BookFormat.story, .movieScript, .verbs])
    func playbackSequencesSlowlyAndStopsWithoutCompleting(format: BookFormat) async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress)
        let source = sample()
        let book = Book(id: "script", title: source.title, englishTitle: source.englishTitle, author: source.author, level: source.level, symbol: source.symbol, palette: 0, summary: source.summary,
            sentences: [Sentence(id: "a", spanish: "Hola.", english: "Hello.", speaker: "Ana")], vocabulary: [], license: "Test", format: format,
            continuation: [Sentence(id: "b", spanish: "Buenas tardes.", english: "Good afternoon.", speaker: "Leo")])
        _ = try await learning.advance(book: book, from: 0)
        let audio = ReaderTestAudio(), probe = ReaderPauseProbe()
        let vm = BookReaderViewModel(learning: learning, audio: audio, pause: { await probe.pause() })
        #expect(vm.audioEnabled)
        vm.start(book)
        for _ in 0..<100 where audio.spoken.isEmpty { await Task.yield() }
        #expect(audio.spoken == ["Hola."])
        #expect(audio.rates == [true]); #expect(vm.activeIndex == 0)
        audio.finishLine()
        for _ in 0..<100 where audio.spoken.count < 2 { await Task.yield() }
        #expect(audio.spoken == ["Hola.", "Buenas tardes."])
        #expect(await probe.count == 1)
        vm.stop()
        #expect(!vm.audioEnabled); #expect(vm.activeIndex == nil)
        #expect(progress.snapshot.completed.isEmpty)
        vm.toggleAudio(book)
        for _ in 0..<100 where audio.spoken.count < 3 { await Task.yield() }
        #expect(audio.spoken.last == "Buenas tardes.")
        #expect(vm.audioEnabled)
        audio.finishLine()
        for _ in 0..<100 where vm.audioEnabled { await Task.yield() }
        #expect(!vm.audioEnabled)
        #expect(progress.snapshot.completed.isEmpty)
        await vm.finish(book)
        #expect(vm.receipt?.total == 1)
    }
}
