import Foundation

struct PracticeStats {
    let total: Int
    let distinct: Int
    let families: Int
    let previous: Int?
    var newWords: Int? { previous.map { distinct - $0 } }
}
@MainActor protocol PracticeFeature: AnyObject {
    func allowed(_ book: Book) -> Bool
    func stats(_ book: Book) -> PracticeStats
    func glossary(_ book: Book) -> [String: String]?
    func recordScore(_ book: Book, matches: Int, elapsed: Double?) async throws
    func best(_ book: Book) -> Int
    func fastestTime(_ book: Book, daily: Bool) -> Double?
    var coins: Int { get }
    var week: [WeekDay] { get }
    var dailyChallenge: DailyMatchChallenge? { get }
    func dailyDeck(_ book: Book, day: String) throws -> [String]
    @discardableResult func finishDailyGame(_ book: Book, day: String, words: Set<String>, elapsed: Double?) async throws -> MatchRewardReceipt?
}
@MainActor final class PracticeManager: PracticeFeature {
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    init(progress: any ProgressFeature, purchases: any PurchaseFeature) { self.progress = progress; self.purchases = purchases }
    func allowed(_ book: Book) -> Bool { purchases.hasAccess && progress.snapshot.completed.contains(book.id) }
    func stats(_ book: Book) -> PracticeStats {
        let words = Set(book.vocabulary.map(\.word))
        return .init(total: book.wordCount, distinct: words.count, families: Set(book.vocabulary.map(\.lemma)).count,
                     previous: progress.snapshot.bookWordBaselines?[book.id].map { words.intersection($0).count })
    }
    func glossary(_ book: Book) -> [String: String]? {
        guard let glossary = book.matchGlossary,
              Set(glossary.keys) == Set(book.vocabulary.map(\.word)), glossary.values.allSatisfy({ !$0.isEmpty }) else { return nil }
        return glossary
    }
    func recordScore(_ book: Book, matches: Int, elapsed: Double? = nil) async throws {
        guard allowed(book), glossary(book) != nil else { throw AppFailure.locked }
        try await progress.recordPractice(book: book, matches: matches, elapsed: elapsed)
    }
    var dailyChallenge: DailyMatchChallenge? { purchases.hasAccess ? progress.dailyChallenge : nil }
    func dailyDeck(_ book: Book, day: String) throws -> [String] {
        guard allowed(book), let challenge = dailyChallenge, challenge.day == day,
              challenge.bookIDs.contains(book.id), let glossary = glossary(book),
              glossary.count >= DailyMatchChallenge.pairCount else { throw AppFailure.locked }
        return Array(glossary.keys.sorted().shuffled().prefix(DailyMatchChallenge.pairCount))
    }
    @discardableResult func finishDailyGame(_ book: Book, day: String, words: Set<String>, elapsed: Double? = nil) async throws -> MatchRewardReceipt? {
        guard allowed(book), glossary(book) != nil else { throw AppFailure.locked }
        return try await progress.completeDailyGame(book: book, day: day, words: words, elapsed: elapsed)
    }
    func best(_ book: Book) -> Int { progress.snapshot.bestMatches?[book.id] ?? 0 }
    func fastestTime(_ book: Book, daily: Bool) -> Double? {
        daily ? progress.snapshot.bestDailyMatchTimes?[book.id] : progress.snapshot.bestFullMatchTimes?[book.id]
    }
    var coins: Int { progress.snapshot.availableChatCoins }
    var week: [WeekDay] { progress.week }
}
