import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct PracticeViewModelTests {
    @Test func wholeDeckAwardsOnceAndInterruptionsDoNotAward() async throws {
        let book = sample()
        var playable = book; playable.matchGlossary = ["está": "is here"]
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        try await progress.recordEncounter(book: playable, sentence: playable.sentences[0]); _ = try await progress.complete(book: playable)
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let model = PracticeViewModel(book: playable, feature: feature)
        model.timed = false; model.startGame()
        model.suspend()
        #expect(model.stage == .ready); #expect(feature.coins == 1)
        model.startGame(); model.stage = .playing
        await model.chooseSpanish("está"); await model.chooseEnglish("está")
        #expect(model.stage == .result); #expect(model.matches == 1)
        model.startGame(); model.stage = .playing
        await model.chooseEnglish("está"); await model.chooseSpanish("está")
        #expect(feature.coins == 1)
    }

    @Test func countdownDoesNotSpendRoundTimeAndLateTapsDoNotScore() async throws {
        var book = sample(); book.matchGlossary = ["está": "is here"]
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        var instant = ContinuousClock().now
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let model = PracticeViewModel(book: book, feature: feature, now: { instant })
        model.startGame()
        await model.chooseSpanish("está")
        #expect(model.selectedSpanish == nil)
        instant = instant.advanced(by: .seconds(3)); await model.tick()
        #expect(model.stage == .playing); #expect(model.seconds == 30)
        instant = instant.advanced(by: .seconds(31))
        await model.chooseSpanish("está"); await model.chooseEnglish("está")
        #expect(model.stage == .result); #expect(model.matches == 0); #expect(feature.coins == 1)
    }
}
