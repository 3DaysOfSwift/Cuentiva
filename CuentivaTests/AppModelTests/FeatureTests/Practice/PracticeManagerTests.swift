//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct PracticeManagerTests {
    @Test func dailyGamesRequireThirtyPairsAndAwardExactlyOnceWithRetryAndRelaunch() async throws {
        #if canImport(CuentivaAppModel)
        let url = TestResources.repositoryRoot.appending(path: "Cuentiva/3 - App Resources/Library.dat")
        #else
        let url = try #require(Bundle.main.url(forResource: "Library", withExtension: "dat"))
        #endif
        let books = Array(try BinaryLibrary(url: url).books().prefix(3))
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = MemoryProgress()
        var saved = LearnerProgress(); saved.completed = Set(books.map(\.id)); saved.doubloons = 0
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository, now: { now }); try await progress.load()
        try await progress.saveDailyReading(books.map(\.id), date: now)
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let challenge = try #require(feature.dailyChallenge)
        let first = try #require(books.first), last = try #require(books.last)
        let deck = try feature.dailyDeck(first, day: challenge.day)
        #expect(deck.count == 30 && Set(deck).count == 30)
        await #expect(throws: AppFailure.self) {
            try await feature.finishDailyGame(first, day: challenge.day, words: Set(deck.dropLast()))
        }
        try await feature.recordScore(first, matches: 30)
        #expect(feature.dailyChallenge?.completedBookIDs.isEmpty == true)
        for (index, book) in books.dropLast().enumerated() {
            let receipt = try #require(try await feature.finishDailyGame(book, day: challenge.day, words: Set(feature.dailyDeck(book, day: challenge.day))))
            #expect(receipt.previousBalance == index)
            #expect(receipt.balance == index + 1)
        }
        #expect(feature.coins == 2)
        let lastWords = Set(try feature.dailyDeck(last, day: challenge.day))
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) {
            try await feature.finishDailyGame(last, day: challenge.day, words: lastWords)
        }
        #expect(feature.coins == 2)
        #expect(feature.dailyChallenge?.completedBookIDs.count == 2)
        await repository.setFailure(false)
        let receipt = try #require(try await feature.finishDailyGame(last, day: challenge.day, words: lastWords))
        #expect(receipt.previousBalance == 2 && receipt.balance == 3)
        #expect(feature.coins == 3)
        #expect(feature.dailyChallenge?.rewarded == true)
        let reloaded = ProgressManager(repository: repository, now: { now }); try await reloaded.load()
        let restored = PracticeManager(progress: reloaded, purchases: purchases)
        let replay = try await restored.finishDailyGame(last, day: challenge.day, words: lastWords)
        #expect(replay == nil)
        #expect(restored.coins == 3)
        let records = try ProgressRecords.encode(reloaded.snapshot)
        #expect(try ProgressRecords.decode(records) == reloaded.snapshot)
        purchases.hasAccess = false
        #expect(restored.dailyChallenge == nil)
        #expect(throws: AppFailure.self) { try restored.dailyDeck(first, day: challenge.day) }
        purchases.hasAccess = true
        now = now.addingTimeInterval(86_400)
        #expect(restored.dailyChallenge == nil)
        await #expect(throws: AppFailure.self) {
            try await restored.finishDailyGame(last, day: challenge.day, words: lastWords)
        }
        try await reloaded.saveDailyReading(books.map(\.id), date: now)
        #expect(restored.dailyChallenge?.completedBookIDs.isEmpty == true)
        #expect(restored.coins == 3)
    }

    @Test func legacyGroupRewardsRemainPaidAndConcurrentReplaysOnlyAwardOnce() async throws {
        #if canImport(CuentivaAppModel)
        let url = TestResources.repositoryRoot.appending(path: "Cuentiva/3 - App Resources/Library.dat")
        #else
        let url = try #require(Bundle.main.url(forResource: "Library", withExtension: "dat"))
        #endif
        let books = Array(try BinaryLibrary(url: url).books().prefix(3))
        let book = try #require(books.first)
        let repository = MemoryProgress()
        let now = Date()
        var saved = LearnerProgress(); saved.completed = Set(books.map(\.id)); saved.doubloons = 5
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository, now: { now }); try await progress.load()
        try await progress.saveDailyReading(books.map(\.id), date: now)
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let day = try #require(feature.dailyChallenge?.day)
        let words = Set(try feature.dailyDeck(book, day: day))
        async let first = feature.finishDailyGame(book, day: day, words: words)
        async let second = feature.finishDailyGame(book, day: day, words: words)
        let receipts = try await [first, second].compactMap { $0 }
        #expect(receipts.count == 1)
        #expect(receipts.first?.previousBalance == 5 && receipts.first?.balance == 6)
        #expect(feature.coins == 6)

        let legacyJSON = try JSONSerialization.data(withJSONObject: [
            "day": day, "bookIDs": books.map(\.id),
            "completedBookIDs": books.map(\.id), "rewarded": true
        ])
        let legacy = try JSONDecoder().decode(DailyMatchChallenge.self, from: legacyJSON)
        #expect(legacy.rewardedBookIDs == nil)
        #expect(legacy.paidBookIDs == Set(books.map(\.id)))
        saved.dailyMatchChallenge = legacy
        try await repository.save(saved)
        let reloaded = ProgressManager(repository: repository, now: { now }); try await reloaded.load()
        let restored = PracticeManager(progress: reloaded, purchases: purchases)
        let replay = try await restored.finishDailyGame(book, day: day, words: words)
        #expect(replay == nil)
        #expect(restored.coins == 5)
    }

    @Test func fastestTimesPersistAndOnlyImproveForCompletedComparableGames() async throws {
        #if canImport(CuentivaAppModel)
        let url = TestResources.repositoryRoot.appending(path: "Cuentiva/3 - App Resources/Library.dat")
        #else
        let url = try #require(Bundle.main.url(forResource: "Library", withExtension: "dat"))
        #endif
        let books = Array(try BinaryLibrary(url: url).books().prefix(3))
        let book = try #require(books.first)
        let repository = MemoryProgress()
        var saved = LearnerProgress(); saved.completed = Set(books.map(\.id)); saved.doubloons = 0
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository); try await progress.load()
        try await progress.saveDailyReading(books.map(\.id), date: Date())
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let day = try #require(feature.dailyChallenge?.day)
        let words = Set(try feature.dailyDeck(book, day: day))
        for invalid in [0.0, -1, .infinity, .nan] {
            await #expect(throws: AppFailure.self) {
                try await feature.finishDailyGame(book, day: day, words: words, elapsed: invalid)
            }
        }
        #expect(feature.coins == 0)
        #expect(feature.fastestTime(book, daily: true) == nil)
        try await feature.finishDailyGame(book, day: day, words: words, elapsed: 80)
        try await feature.finishDailyGame(book, day: day, words: words, elapsed: 100)
        #expect(feature.fastestTime(book, daily: true) == 80)
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) {
            try await feature.finishDailyGame(book, day: day, words: words, elapsed: 60)
        }
        #expect(feature.fastestTime(book, daily: true) == 80)
        await repository.setFailure(false)
        let replay = try await feature.finishDailyGame(book, day: day, words: words, elapsed: 60)
        #expect(replay == nil && feature.coins == 1)
        #expect(feature.fastestTime(book, daily: true) == 60)
        await #expect(throws: AppFailure.self) {
            try await feature.recordScore(book, matches: 10, elapsed: 5)
        }
        #expect(feature.fastestTime(book, daily: false) == nil)
        try await feature.recordScore(book, matches: book.vocabulary.count, elapsed: 200)
        try await feature.recordScore(book, matches: book.vocabulary.count, elapsed: 250)
        #expect(feature.fastestTime(book, daily: false) == 200)
        #expect(feature.fastestTime(book, daily: true) == 60)
        let rows = try ProgressRecords.encode(progress.snapshot)
        let decoded = try ProgressRecords.decode(rows)
        #expect(decoded == progress.snapshot)
        let reloaded = ProgressManager(repository: repository); try await reloaded.load()
        let restored = PracticeManager(progress: reloaded, purchases: purchases)
        #expect(restored.fastestTime(book, daily: true) == 60)
        #expect(restored.fastestTime(book, daily: false) == 200)
        #expect(restored.fastestTime(books[1], daily: true) == nil)
    }

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
