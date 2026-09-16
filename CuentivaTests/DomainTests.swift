import Foundation
import Testing
import StoreKit
#if canImport(CuentivaCore)
@testable import CuentivaCore
#else
@testable import Cuentiva
#endif

actor MemoryProgress: ProgressRepository {
    var value = LearnerProgress()
    var fail = false
    func load() -> LearnerProgress { value }
    func save(_ value: LearnerProgress) throws {
        if fail { throw AppFailure.unavailable("Disk full") }
        self.value = value
    }
    func setFailure(_ value: Bool) { fail = value }
}
actor MemoryContributions: ContributionRepository {
    var values: [Contribution] = []
    func drafts() -> [Contribution] { values }
    func save(_ value: Contribution) { values.removeAll { $0.id == value.id }; values.append(value) }
}
struct MemoryBooks: BookRepository {
    let values: [Book]
    func books() async throws -> [Book] { values }
}
@MainActor final class TestPurchases: PurchaseFeature {
    var hasAccess = false
    var checking = false
    var offer: Product? { nil }
    var message: String?
    func refresh() async {}
    func purchase() async throws { hasAccess = true }
    func restore() async throws {}
}
func sample(_ id: String = "cafe", sentences: Int = 1) -> Book {
    Book(id: id, title: "Mi café", englishTitle: "My café", author: "Demo", level: "A1", symbol: "cup.and.saucer", palette: 0, summary: "Sample", sentences: (0..<sentences).map { Sentence(id: "s\($0)", spanish: "El café está aquí.", english: "The café is here.") }, vocabulary: [.init(word: "está", lemma: "estar", occurrences: 1)], license: "Test")
}
@Suite struct WordComparisonTests {
    @Test func omittedWordDoesNotShiftFollowingMatches() {
        let result = WordComparison.compare(expected: "El mundo está lleno de vida", received: "El mundo lleno de vida")
        #expect(result.words.map(\.result) == [.correct, .correct, .missing, .correct, .correct, .correct])
    }
    @Test func accentsPunctuationAndEnye() {
        let result = WordComparison.compare(expected: "¡El café está aquí!", received: "el cafe esta aqui")
        #expect(result.words.map(\.result) == [.correct, .accent, .accent, .accent])
        #expect(WordComparison.compare(expected: "año", received: "ano").words.first?.result == .incorrect)
    }
    @Test func insertionAndRepeatedWords() {
        let result = WordComparison.compare(expected: "Yo veo la casa", received: "Yo también veo la casa")
        #expect(result.matched == 4); #expect(result.extraWords == ["también"])
        #expect(WordComparison.compare(expected: "la la casa", received: "la casa").matched == 2)
    }
}
@Suite @MainActor struct ProgressTests {
    @Test func completionIsIdempotentAndSurvivesReload() async throws {
        let repository = MemoryProgress(), book = sample()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        let first = try await progress.complete(book: book), second = try await progress.complete(book: book)
        #expect(first.isNew); #expect(!second.isNew); #expect(second.total == 1)
        let restored = ProgressManager(repository: repository); try await restored.load()
        #expect(restored.snapshot.completed == [book.id]); #expect(restored.snapshot.vocabulary["estar"] == .learning)
    }
    @Test func incompleteBookCannotFinish() async throws {
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        await #expect(throws: AppFailure.self) { try await progress.complete(book: sample()) }
        #expect(progress.snapshot.completed.isEmpty)
    }
    @Test func failedPersistenceDoesNotPublishSuccess() async throws {
        let repo = MemoryProgress(), book = sample(); let progress = ProgressManager(repository: repo); try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); await repo.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.complete(book: book) }
        #expect(progress.snapshot.completed.isEmpty)
        await repo.setFailure(false); _ = try await progress.complete(book: book)
        #expect(progress.snapshot.completed.count == 1)
    }
    @Test func streakUsesCalendarDaysAndPreservesBooks() async throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = ProgressManager(repository: MemoryProgress(), now: { now }, calendar: calendar)
        let book = sample(); try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        #expect(progress.streak == 1)
        now = calendar.date(byAdding: .day, value: 1, to: now)!
        #expect(progress.streak == 1)
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); #expect(progress.streak == 2)
        now = calendar.date(byAdding: .day, value: 2, to: now)!
        #expect(progress.streak == 0); #expect(progress.snapshot.completed.count == 1)
    }
    @Test func exposureDoesNotBecomeKnownAutomatically() async throws {
        let progress = ProgressManager(repository: MemoryProgress()), book = sample(); try await progress.load()
        for _ in 0..<3 { try await progress.recordEncounter(book: book, sentence: book.sentences[0]) }
        #expect(progress.snapshot.vocabulary["estar"] == .learning)
        #expect(progress.snapshot.evidence["estar"] == 1)
        try await progress.setVocabulary("estar", state: .known)
        #expect(progress.snapshot.vocabulary["estar"] == .known)
    }
}
@Suite @MainActor struct AccessAndContributionTests {
    @Test func introductoryBookIsTheOnlyFreeBook() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress), intro = sample(), paid = sample("paid")
        #expect(learning.canRead(intro)); #expect(!learning.canRead(paid))
        await #expect(throws: AppFailure.self) { try await learning.check(book: paid, sentence: paid.sentences[0], answer: "hola") }
        _ = try await learning.check(book: intro, sentence: intro.sentences[0], answer: "el cafe esta aqui")
        _ = try await learning.finish(intro)
        #expect(!learning.canRead(intro))
        purchases.hasAccess = true; #expect(learning.canRead(paid)); #expect(learning.canRead(intro))
        purchases.hasAccess = false; #expect(!learning.canRead(paid)); #expect(progress.snapshot.completed.count == 1)
    }
    @Test func readingAloneCompletesBookAndResumesWithoutChecks() async throws {
        let repository = MemoryProgress()
        let purchases = TestPurchases(), progress = ProgressManager(repository: repository)
        try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress), book = sample(sentences: 2)
        let step = try await learning.advance(book: book, from: 0)
        if case .position(let position) = step { #expect(position == 1) }
        else { Issue.record("The first sentence prematurely completed the book") }
        #expect(progress.snapshot.attempts[book.id] == ["s0"])
        let restored = ProgressManager(repository: repository); try await restored.load()
        #expect(restored.snapshot.positions[book.id] == 1)
        let result = try await learning.advance(book: book, from: 1)
        if case .completed(let receipt) = result { #expect(receipt.total == 1); #expect(receipt.isNew) }
        else { Issue.record("Reading the final sentence did not complete the book") }
        #expect(progress.streak == 1)
        #expect(progress.snapshot.vocabulary["estar"] == .learning)
        #expect(!learning.canRead(book))
        purchases.hasAccess = true
        let reread = try await learning.advance(book: book, from: 1)
        if case .completed(let receipt) = reread { #expect(!receipt.isNew); #expect(receipt.total == 1) }
    }
    @Test func failedReadingSaveDoesNotAdvanceOrComplete() async throws {
        let repository = MemoryProgress()
        let failingProgress = ProgressManager(repository: repository)
        try await failingProgress.load(); await repository.setFailure(true)
        let learning = LearningManager(purchases: TestPurchases(), progress: failingProgress)
        await #expect(throws: AppFailure.self) { try await learning.advance(book: sample(), from: 0) }
        #expect(failingProgress.snapshot.completed.isEmpty)
        #expect(failingProgress.snapshot.attempts.isEmpty)
        #expect(failingProgress.snapshot.positions.isEmpty)
    }
    @Test func librarySearchAndCompletedCollectionAreGated() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress()), book = sample(); try await progress.load()
        let library = LibraryManager(repository: MemoryBooks(values: [book]), purchases: purchases, progress: progress); try await library.load()
        #expect(library.search("", level: nil, completedOnly: false).isEmpty)
        purchases.hasAccess = true
        #expect(library.search("cafe", level: "A1", completedOnly: false).count == 1)
        #expect(library.search("", level: "B1", completedOnly: false).isEmpty)
        #expect(library.search("", level: nil, completedOnly: true).isEmpty)
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        #expect(library.search("", level: nil, completedOnly: true).count == 1)
    }
    @Test func localSubmissionNeverClaimsPublication() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress()), repo = MemoryContributions()
        try await progress.load(); purchases.hasAccess = true
        let manager = ContributionManager(repository: repo, purchases: purchases, progress: progress)
        #expect(!manager.eligible)
        let book = sample(); try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        #expect(manager.eligible)
        var draft = Contribution(); draft.title = "Mi historia"; draft.spanish = "Yo vivo en una casa bonita cerca de un parque pequeño."
        try await manager.save(draft, submit: true)
        #expect(manager.drafts.first?.status == "Pending review · local demo"); #expect(manager.publishedCount == 0)
    }
    @Test func bundledContentIsAlignedAndIndexed() async throws {
        #if canImport(CuentivaCore)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: "Cuentiva/3 - App Resources/Books.json")
        #else
        let url = Bundle.main.url(forResource: "Books", withExtension: "json")!
        #endif
        let books = try await BundledBookRepository(url: url).books()
        #expect(books.count == 5); #expect(Set(books.map(\.level)) == ["A1", "A2", "B1"])
        for book in books {
            let words = book.sentences.flatMap { WordComparison.words($0.spanish).map(WordComparison.normalized) }
            #expect(Set(words) == Set(book.vocabulary.map(\.word)))
            #expect(book.vocabulary.reduce(0) { $0 + $1.occurrences } == words.count)
        }
    }
}

@Suite struct PersistenceTests {
    @Test func atomicProgressFileRoundTrip() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = LocalProgressRepository(url: folder.appending(path: "progress.json"))
        var value = LearnerProgress(); value.completed = ["cafe"]; value.positions["garden"] = 3
        try await repo.save(value)
        let reloaded = try await repo.load()
        #expect(reloaded.completed == ["cafe"]); #expect(reloaded.positions["garden"] == 3)
    }
    @Test func corruptDataDoesNotSilentlyResetProgress() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "progress.json")
        try Data("not-json".utf8).write(to: url)
        await #expect(throws: (any Error).self) { try await LocalProgressRepository(url: url).load() }
    }
}
