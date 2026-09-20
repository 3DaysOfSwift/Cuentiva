import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct DailyPracticeViewModelTests {
    @Test func eachFinishedSentenceCelebratesAndFinalCounterReachesFive() async throws {
        let repo = MemoryProgress()
        let progress = ProgressManager(repository: repo); try await progress.load()
        let books = (0..<3).map { sample("b\($0)", sentences: 4) }
        try await progress.saveDailyReading(books.map(\.id), date: .now)
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = DailyPracticeManager(progress: progress, purchases: purchases)
        let model = DailyPracticeViewModel(books: books, feature: feature)
        await model.prepare(); model.select(.sentenceBuilder)
        let rounds = try #require(model.session?.rounds)
        for round in 0..<rounds {
            let phrase = try #require(model.session?.builderPhrase)
            for index in phrase.words.indices {
                await model.choose(String(index))
                if index < phrase.words.count - 1 { #expect(model.celebrationID == nil) }
            }
            #expect(model.celebrationID != nil && model.completedRounds == round)
            // Leaving during the celebration must not lose or repeat saved progress.
            let animation = Task { await model.celebrateRound() }
            animation.cancel()
            await animation.value
            #expect(model.celebrationID == nil && model.completedRounds == round + 1)
        }
        #expect(model.session?.completed.contains(.sentenceBuilder) == true)
        #expect(model.completedRounds == 5)
        #expect(!model.showingReward)
        #expect(progress.snapshot.doubloons == 1)
        model.completePractice()
        #expect(model.showingReward)
        model.completePractice()
        #expect(progress.snapshot.doubloons == 1)
        let resumed = DailyPracticeViewModel(books: books, feature: feature)
        resumed.selected = .sentenceBuilder
        #expect(resumed.completedRounds == 5)
        resumed.select(.sentenceBuilder)
        resumed.completePractice()
        #expect(resumed.showingReward && progress.snapshot.doubloons == 1)
    }
    @Test func unavailableAccessAndFailedSavesRemainRetryable() async throws {
        let repo = MemoryProgress()
        let progress = ProgressManager(repository: repo)
        try await progress.load()
        let books = (0..<3).map { sample("b\($0)", sentences: 4) }
        try await progress.saveDailyReading(books.map(\.id), date: .now)
        let purchases = TestPurchases()
        purchases.hasAccess = false
        let feature = DailyPracticeManager(progress: progress, purchases: purchases)
        let model = DailyPracticeViewModel(books: books, feature: feature)
        await model.prepare()
        #expect(model.error != nil)
        #expect(model.session == nil)
        purchases.hasAccess = true
        await model.prepare()
        model.select(.missingWord)
        let answer = try #require(model.session?.missingAnswer)
        await repo.setFailure(true)
        await model.choose(answer)
        #expect(model.error != nil)
        #expect(model.session?.missingIndex == 0)
        #expect(!model.busy)
        #expect(model.celebrationID == nil && model.completedRounds == 0)
        await repo.setFailure(false)
        await model.choose(answer)
        #expect(model.error == nil)
        #expect(model.session?.missingIndex == 1)
        #expect(model.feedback == nil)
        #expect(model.celebrationID != nil && model.completedRounds == 0)
        #expect(model.displayedSession?.missingIndex == 0)
        await model.choose(answer)
        #expect(model.session?.missingIndex == 1)
        await model.celebrateRound()
        #expect(model.celebrationID == nil && model.completedRounds == 1)
        #expect(model.displayedSession?.missingIndex == 1)
    }
}
