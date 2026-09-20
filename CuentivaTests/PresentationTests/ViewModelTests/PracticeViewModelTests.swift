import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct PracticeViewModelTests {
    @Test func dailyGamesRevealEachSavedRewardAndRetryFailures() async throws {
        let url = try #require(Bundle.main.url(forResource: "Library", withExtension: "dat"))
        let books = Array(try BinaryLibrary(url: url).books().prefix(3))
        let repository = MemoryProgress()
        var saved = LearnerProgress(); saved.completed = Set(books.map(\.id)); saved.doubloons = 0
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository); try await progress.load()
        try await progress.saveDailyReading(books.map(\.id), date: Date())
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let challenge = try #require(feature.dailyChallenge)
        for (index, book) in books.enumerated() {
            var instant = ContinuousClock().now
            let model = PracticeViewModel(book: book, challengeDay: challenge.day, feature: feature, now: { instant })
            model.prepareGame(); model.startGame(); model.suspend()
            #expect(model.stage == .ready)
            #expect(feature.dailyChallenge?.completedBookIDs.contains(book.id) == false)
            model.startGame()
            #expect(!model.timed)
            #expect(model.elapsed == 0)
            instant = instant.advanced(by: .seconds(3)); await model.tick()
            #expect(model.elapsed == 0) // Countdown is excluded.
            for pair in 0..<30 {
                instant = instant.advanced(by: .seconds(2))
                await model.tick()
                if index == 2 && pair == 29 { await repository.setFailure(true) }
                let word = try #require(model.board.first)
                let meanings = model.board.compactMap { model.glossary?[$0] }
                #expect(Set(meanings).count == meanings.count)
                await model.chooseSpanish(word); await model.chooseEnglish(word)
            }
            #expect(model.stage == .result)
            #expect(model.matches == 30)
            #expect(model.elapsed == 60)
            #expect(model.elapsedText == "01:00.0")
            instant = instant.advanced(by: .seconds(10)); await model.tick()
            #expect(model.elapsed == 60) // Results and storage retries do not add time.
            #expect(model.remaining.isEmpty && model.board.isEmpty)
            if index == 2 {
                #expect(model.error != nil)
                #expect(model.rewardReceipt == nil)
                #expect(feature.coins == 2)
                #expect(feature.fastestTime(book, daily: true) == nil)
                await repository.setFailure(false)
                await model.saveScore()
            }
            #expect(model.error == nil)
            #expect(model.fastestTimeText == "01:00.0")
            let receipt = try #require(model.rewardReceipt)
            #expect(receipt.previousBalance == index && receipt.balance == index + 1)
            model.rewardReceipt = nil
            await model.saveScore()
            #expect(model.rewardReceipt == nil)
            #expect(feature.coins == index + 1)
            #expect(feature.dailyChallenge?.completedBookIDs.contains(book.id) == true)
        }
        #expect(feature.coins == 3)
    }

    @Test func fullDeckClockExcludesCountdownAndInterruptedRoundsDoNotBeatBest() async throws {
        var book = sample(); book.matchGlossary = ["está": "is here"]
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        var instant = ContinuousClock().now
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let model = PracticeViewModel(book: book, feature: feature, now: { instant })
        model.timed = false; model.startGame()
        instant = instant.advanced(by: .seconds(3)); await model.tick()
        #expect(model.elapsed == 0)
        instant = instant.advanced(by: .seconds(2))
        await model.chooseSpanish("está"); await model.chooseEnglish("está")
        #expect(model.elapsed == 2)
        #expect(model.fastestTimeText == "00:02.0")
        #expect(feature.fastestTime(book, daily: true) == nil)
        model.startGame()
        instant = instant.advanced(by: .seconds(3)); await model.tick()
        instant = instant.advanced(by: .seconds(1)); await model.tick()
        model.suspend()
        #expect(model.stage == .ready)
        #expect(feature.fastestTime(book, daily: false) == 2)
    }

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
