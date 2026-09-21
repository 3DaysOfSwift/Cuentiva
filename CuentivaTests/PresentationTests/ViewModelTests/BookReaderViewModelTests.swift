//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct BookReaderViewModelTests {
    @Test func wholeBookIncludesEndingWithNoAutomaticAudioOrTranslations() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress)
        var book = sample()
        book.continuation = [.init(id: "middle", spanish: "Sigue.", english: "Continues.")]
        book.ending = [.init(id: "end", spanish: "Fin.", english: "End.")]
        let audio = TestAudio()
        let model = BookReaderViewModel(learning: learning, audio: audio)
        #expect(model.passages(book).count == 3)
        #expect(model.passages(book).last?.id == "end")
        model.start(book)
        #expect(!model.audioEnabled)
        #expect(model.activeIndex == nil)
        #expect(model.revealed.isEmpty)
        #expect(progress.snapshot.completed.isEmpty)
    }

    @Test func silentGuideHighlightsAllChaptersWithoutAudioOrCompletion() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress)
        var book = sample()
        book.continuation = [.init(id: "middle", spanish: "Sigue.", english: "Continues.")]
        book.ending = [.init(id: "end", spanish: "Fin.", english: "End.")]
        let gate = ReaderWordGate(), audio = ReaderTestAudio()
        let model = BookReaderViewModel(learning: learning, audio: audio, pause: {}, wordPause: { _ in await gate.wait() })
        defer { model.stop(); gate.release() }
        model.toggleGuide(book)
        for (step, index) in [0, 0, 0, 0, 1, 2].enumerated() {
            try await waitUntil { gate.calls == step + 1 && gate.pending != nil }
            #expect(model.activeIndex == index)
            #expect(model.highlightedRange != nil)
            #expect(audio.spoken.isEmpty)
            gate.release()
        }
        try await waitUntil { !model.isPlaying }
        #expect(model.highlightedRange == nil)
        #expect(model.revealed.isEmpty)
        #expect(progress.snapshot.completed.isEmpty)
    }

    @Test func audioToggleAndPauseKeepTheCurrentSentence() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress)
        let book = sample(), gate = ReaderWordGate(), audio = ReaderTestAudio()
        let model = BookReaderViewModel(learning: learning, audio: audio, pause: {}, wordPause: { _ in await gate.wait() })
        defer { model.stop(); gate.release() }
        model.toggleAudio(book)
        #expect(model.audioEnabled && !model.isPlaying)
        model.toggleGuide(book)
        try await waitUntil { audio.pending != nil }
        #expect(audio.rates == [true])
        model.toggleAudio(book)
        try await waitUntil { gate.pending != nil }
        #expect(!model.audioEnabled && model.isPlaying)
        #expect(model.activeIndex == 0)
        #expect(model.highlightedRange != nil)
        model.toggleGuide(book)
        gate.release()
        #expect(!model.isPlaying)
        model.toggleGuide(book)
        try await waitUntil { gate.pending != nil }
        #expect(model.activeIndex == 0)
        #expect(progress.snapshot.completed.isEmpty)
    }

    @Test(arguments: [BookFormat.story, .movieScript, .verbs])
    func playbackSequencesSlowlyAndStopsWithoutCompleting(format: BookFormat) async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress)
        let source = sample()
        let book = Book(id: "script", title: source.title, englishTitle: source.englishTitle, author: source.author, level: source.level, symbol: source.symbol, palette: 0, summary: source.summary,
            sentences: [Sentence(id: "a", spanish: "Hola.", english: "Hello.", speaker: "Ana")], vocabulary: [], license: "Test", format: format,
            continuation: [Sentence(id: "b", spanish: "Buenas tardes.", english: "Good afternoon.", speaker: "Leo"), Sentence(id: "c", spanish: "Adiós.", english: "Goodbye.", speaker: "Ana")], ending: [Sentence(id: "d", spanish: "Fin.", english: "End.")])
        _ = try await learning.advance(book: book, from: 0)
        let audio = ReaderTestAudio(), probe = ReaderPauseProbe()
        let vm = BookReaderViewModel(chapterTwo: true, learning: learning, audio: audio, pause: { await probe.pause() })
        #expect(vm.audioEnabled)
        vm.start(book)
        for _ in 0..<100 where audio.spoken.isEmpty { await Task.yield() }
        #expect(audio.spoken == ["Buenas tardes."])
        #expect(audio.rates == [true]); #expect(vm.activeIndex == 0)
        audio.finishLine()
        for _ in 0..<100 where audio.spoken.count < 2 { await Task.yield() }
        #expect(audio.spoken == ["Buenas tardes.", "Adiós."])
        #expect(await probe.count == 1)
        vm.stop()
        #expect(!vm.audioEnabled); #expect(vm.activeIndex == nil)
        #expect(progress.snapshot.completed.isEmpty)
        vm.toggleAudio(book)
        for _ in 0..<100 where audio.spoken.count < 3 { await Task.yield() }
        #expect(audio.spoken.last == "Adiós.")
        #expect(vm.audioEnabled)
        audio.finishLine()
        for _ in 0..<100 where vm.audioEnabled { await Task.yield() }
        #expect(!vm.audioEnabled)
        #expect(progress.snapshot.completed.isEmpty)
        #expect(await vm.finishChapter(book) == 3)
        #expect(progress.snapshot.completed.isEmpty)
        #expect(progress.snapshot.attempts[book.id] == ["a", "b", "c"])
    }
}

@MainActor private final class ReaderWordGate {
    var calls = 0
    var pending: CheckedContinuation<Void, Never>?
    func wait() async { calls += 1; await withCheckedContinuation { pending = $0 } }
    func release() { let value = pending; pending = nil; value?.resume() }
}
