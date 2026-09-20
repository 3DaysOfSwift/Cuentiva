import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct PracticeManagerTests {
    @Test func everyBundledBookSupportsMatchingAfterCompletion() async throws {
        #if canImport(CuentivaAppModel)
        let url = TestResources.repositoryRoot.appending(path: "Cuentiva/3 - App Resources/Library.dat")
        #else
        let url = try #require(Bundle.main.url(forResource: "Library", withExtension: "dat"))
        #endif
        let books = try BinaryLibrary(url: url).books()
        #expect(books.count == 52)
        let repository = MemoryProgress()
        var saved = LearnerProgress()
        saved.completed = Set(books.map(\.id))
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let startingCoins = feature.coins
        for book in books {
            #expect(feature.allowed(book))
            let glossary = try #require(feature.glossary(book))
            #expect(!glossary.isEmpty)
            #expect(Set(glossary.keys) == Set(book.vocabulary.map(\.word)))
            try await feature.recordScore(book, matches: glossary.count)
            #expect(feature.best(book) == glossary.count)
        }
        #expect(feature.coins == startingCoins)
        let train = try #require(books.first { $0.id == "train" })
        let verb = try #require(books.first { $0.id == "verb-ser" })
        let owl = try #require(books.first { $0.id == "patient-investor" })
        #expect(feature.glossary(train)?["sobre"] == "envelope")
        #expect(feature.glossary(verb)?["camino"] == "I walk")
        #expect(feature.glossary(owl)?["cerca"] == "fence")
    }

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
