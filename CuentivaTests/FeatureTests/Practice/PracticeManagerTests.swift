import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct PracticeManagerTests {
    @Test func accessRequiresPurchaseAndCompletionAndScoresDoNotMintCoins() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases()
        let feature = PracticeManager(progress: progress, purchases: purchases)
        var book = sample()
        book.matchGlossary = ["está": "is here"]
        #expect(!feature.allowed(book))
        purchases.hasAccess = true
        #expect(!feature.allowed(book))
        await #expect { try await feature.recordScore(book, matches: 1) } throws: { error in
            guard case AppFailure.locked = error else { return false }
            return true
        }
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        #expect(feature.allowed(book))
        #expect(feature.best(book) == 0)
        let coins = feature.coins
        try await feature.recordScore(book, matches: 1)
        #expect(feature.best(book) == 1)
        #expect(feature.coins == coins)
        #expect(feature.week.count == 7)
        #expect(feature.week.contains { $0.today && $0.practiced })
        purchases.hasAccess = false
        #expect(!feature.allowed(book))
        await #expect { try await feature.recordScore(book, matches: 1) } throws: { error in
            guard case AppFailure.locked = error else { return false }
            return true
        }
    }

    @Test func glossaryRejectsMissingExtraAndEmptyTranslations() {
        let feature = PracticeManager(progress: ProgressManager(repository: MemoryProgress()), purchases: TestPurchases())
        var book = sample()
        #expect(feature.glossary(book) == nil)
        book.matchGlossary = ["está": "is here"]
        #expect(feature.glossary(book) == ["está": "is here"])
        book.matchGlossary = ["está": ""]
        #expect(feature.glossary(book) == nil)
        book.matchGlossary = ["está": "is here", "café": "coffee"]
        #expect(feature.glossary(book) == nil)
        book.matchGlossary = [:]
        #expect(feature.glossary(book) == nil)
    }

    @Test func statisticsUseSavedBaselineAndFailedScoresPreserveBest() async throws {
        let repository = MemoryProgress()
        var saved = LearnerProgress()
        saved.completed = ["cafe"]
        saved.bookWordBaselines = ["cafe": ["está"]]
        saved.bestMatches = ["cafe": 0]
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = PracticeManager(progress: progress, purchases: purchases)
        var book = sample(); book.matchGlossary = ["está": "is here"]
        let stats = feature.stats(book)
        #expect(stats.total == book.wordCount)
        #expect(stats.distinct == 1)
        #expect(stats.families == 1)
        #expect(stats.previous == 1)
        #expect(stats.newWords == 0)
        #expect(feature.stats(sample("unseen")).newWords == nil)
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await feature.recordScore(book, matches: 1) }
        #expect(feature.best(book) == 0)
    }
}
