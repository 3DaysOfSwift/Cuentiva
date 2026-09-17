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
    func reward(_ book: Book, matches: Int) async throws -> Bool
    func best(_ book: Book) -> Int
    var coins: Int { get }
    var week: [WeekDay] { get }
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
    func reward(_ book: Book, matches: Int) async throws -> Bool {
        guard allowed(book), glossary(book) != nil else { throw AppFailure.locked }
        return try await progress.rewardPractice(book: book, matches: matches)
    }
    func best(_ book: Book) -> Int { progress.snapshot.bestMatches?[book.id] ?? 0 }
    var coins: Int { progress.snapshot.doubloons ?? 0 }
    var week: [WeekDay] { progress.week }
}
