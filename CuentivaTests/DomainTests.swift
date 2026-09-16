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
        if case .fullReading = result {} else { Issue.record("Expected the full reader") }
        #expect(progress.snapshot.completed.isEmpty)
        #expect(learning.canRead(book))
        let receipt = try await learning.finishReading(book)
        #expect(receipt.total == 1); #expect(receipt.isNew)
        #expect(progress.streak == 1)
        #expect(progress.snapshot.vocabulary["estar"] == .learning)
        #expect(!learning.canRead(book))
        purchases.hasAccess = true
        let reread = try await learning.advance(book: book, from: 1)
        if case .fullReading = reread {} else { Issue.record("Expected the full reader on rereading") }
        let again = try await learning.finishReading(book)
        #expect(!again.isNew); #expect(again.total == 1)
    }
    @Test func freeIntroductionIncludesContinuationBeforePurchaseGate() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress)
        var intro = sample()
        intro.continuation = [Sentence(id: "extra", spanish: "Otra historia.", english: "Another story.")]
        _ = try await learning.advance(book: intro, from: 0)
        #expect(learning.canRead(intro)); #expect(progress.snapshot.completed.isEmpty)
        #expect(learning.position(intro) == 1)
        _ = try await learning.finishReading(intro)
        #expect(!learning.canRead(intro)); #expect(!learning.canRead(sample("other")))
        #expect(progress.snapshot.completed == ["cafe"])
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
    @Test func formatsCombineWithSearchLevelCompletionAndAccess() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let story = sample("story")
        var script = sample("script"); script.format = .movieScript; script.scene = "A café"
        let library = LibraryManager(repository: MemoryBooks(values: [story, script]), purchases: purchases, progress: progress)
        try await library.load()
        #expect(library.search("", level: nil, completedOnly: false, format: .movieScript, sort: .title).isEmpty)
        purchases.hasAccess = true
        #expect(library.search("cafe", level: "A1", completedOnly: false, format: .movieScript, sort: .title).map(\.id) == ["script"])
        #expect(library.search("cafe", level: "B1", completedOnly: false, format: .movieScript, sort: .title).isEmpty)
        #expect(library.search("", level: nil, completedOnly: false, format: .story, sort: .library).map(\.id) == ["story"])
        #expect(library.search("", level: nil, completedOnly: false, format: nil, sort: .type).map(\.id) == ["script", "story"])
        // Equal titles/difficulty use the stable ID tie-breaker.
        for sort in [BookSort.title, .difficulty] {
            #expect(library.search("", level: nil, completedOnly: false, format: nil, sort: sort).map(\.id) == ["script", "story"])
        }
        #expect(library.search("", level: nil, completedOnly: true, format: .movieScript, sort: .title).isEmpty)
        try await progress.recordEncounter(book: script, sentence: script.sentences[0])
        _ = try await progress.complete(book: script)
        #expect(library.search("", level: nil, completedOnly: true, format: .movieScript, sort: .title).map(\.id) == ["script"])
    }
    @Test(arguments: [BookFormat.story, .movieScript, .verbs])
    func completionWaitsForReaderAndPersistsAtomically(format: BookFormat) async throws {
        let purchases = TestPurchases(), repository = MemoryProgress()
        let progress = ProgressManager(repository: repository); try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress)
        var book = sample("script"); book.format = format
        book.continuation = [Sentence(id: "extra", spanish: "Mañana.", english: "Tomorrow.", speaker: "Ana")]
        await #expect(throws: AppFailure.self) { try await learning.finishReading(book) }
        purchases.hasAccess = true
        await #expect(throws: AppFailure.self) { try await learning.finishReading(book) }
        let stage = try await learning.advance(book: book, from: 0)
        if case .fullReading = stage {} else { Issue.record("Expected the full reader") }
        #expect(progress.snapshot.completed.isEmpty)
        #expect(learning.position(book) == book.sentences.count)
        await #expect(throws: AppFailure.self) { try await learning.finish(book) }
        let restored = ProgressManager(repository: repository); try await restored.load()
        #expect(restored.snapshot.positions[book.id] == 1)
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await learning.finishReading(book) }
        #expect(progress.snapshot.completed.isEmpty)
        #expect(progress.snapshot.attempts[book.id]?.contains("extra") == false)
        await repository.setFailure(false)
        let result = try await learning.finishReading(book)
        #expect(result.isNew); #expect(result.total == 1)
        #expect(progress.snapshot.attempts[book.id]?.contains("extra") == true)
        #expect(progress.snapshot.vocabulary["mañana"] == .learning)
        let repeated = try await learning.finishReading(book)
        #expect(!repeated.isNew); #expect(repeated.total == 1)
    }
    @Test func verbTypeCanBeFilteredAndSearched() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        var verb = sample("verb"); verb.format = .verbs
        let library = LibraryManager(repository: MemoryBooks(values: [sample(), verb]), purchases: purchases, progress: progress)
        try await library.load()
        #expect(library.search("cafe", level: "A1", completedOnly: false, format: .verbs, sort: .title).map(\.id) == ["verb"])
        #expect(library.search("", level: nil, completedOnly: true, format: .verbs, sort: .type).isEmpty)
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
        #expect(books.count == 49); #expect(Set(books.map(\.level)) == ["A1", "A2", "B1"])
        #expect(books.filter { $0.kind == .movieScript }.count == 3)
        #expect(books.filter { $0.kind == .story }.count == 43)
        #expect(books.filter { $0.kind == .verbs }.count == 3)
        for book in books {
            #expect(book.continuation?.count == book.sentences.count)
            #expect(Set(book.fullText.map(\.id)).count == book.fullText.count)
            #expect(book.continuation?.allSatisfy { !$0.spanish.isEmpty && !$0.english.isEmpty } == true)
            if book.kind == .verbs {
                let focus = try #require(book.verbFocus)
                #expect(focus.forms.count == 6)
                #expect(focus.tense == "Present indicative")
                for half in [book.sentences, book.continuation ?? []] {
                    let tokens = half.flatMap { WordComparison.words($0.spanish).map(WordComparison.normalized) }
                    for form in focus.forms { #expect(tokens.contains(form)) }
                }
                for form in focus.forms { #expect(book.vocabulary.first { $0.word == form }?.lemma == focus.infinitive) }
            }
            if book.kind == .movieScript {
                #expect(book.scene?.isEmpty == false)
                #expect(book.cast.count == 2)
                #expect(book.continuation?.count == book.sentences.count)
                #expect(book.sentences.allSatisfy { $0.speaker?.isEmpty == false })
            }
            let words = book.fullText.flatMap { WordComparison.words($0.spanish).map(WordComparison.normalized) }
            #expect(Set(words) == Set(book.vocabulary.map(\.word)))
            #expect(Set(book.vocabulary.map(\.word)).count == book.vocabulary.count)
            for entry in book.vocabulary {
                #expect(!entry.lemma.isEmpty)
                #expect(entry.occurrences == words.filter { $0 == entry.word }.count)
            }
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

@Suite @MainActor struct TopicContributionTests {
    @Test func topicSubmissionChecksTeachingButDoesNotFillCoverage() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let book = sample(); try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        let repo = MemoryContributions()
        let manager = ContributionManager(repository: repo, purchases: purchases, progress: progress)
        try await manager.load()
        let topic = try #require(manager.topics.first { $0.id == "haber-introductions" })
        var draft = Contribution(); draft.title = "Una bienvenida"; draft.topicID = topic.id
        try await manager.save(draft, submit: false)
        await #expect(throws: AppFailure.self) { try await manager.save(draft, submit: true) }
        draft.spanish = "He venido. He hablado. Has venido. Has hablado. Ha venido. Ha hablado. Hemos venido. Hemos hablado. Habéis venido. Habéis hablado. Han venido. Han hablado."
        draft.teachingNote = "Haber helps form compound tenses; explain each example in the story."
        draft.checkedRequirements = topic.requirements
        #expect(topic.ready(draft))
        try await manager.save(draft, submit: true)
        #expect(manager.drafts.count == 1)
        #expect(manager.drafts[0].status == "Pending review · local demo")
        #expect(manager.publishedCount == 0); #expect(!topic.covered); #expect(topic.reviewedBooks == 0)
        let reloaded = ContributionManager(repository: repo, purchases: purchases, progress: progress); try await reloaded.load()
        #expect(reloaded.drafts.first?.topicID == topic.id)
        #expect(reloaded.drafts.first?.teachingNote == draft.teachingNote)
        draft.spanish = draft.spanish.replacingOccurrences(of: "Habéis", with: "Habeis")
        #expect(!topic.ready(draft))
    }
    @Test func coverageAndWordEvidenceAreNotDraftCounts() async throws {
        let topic = TopicRequest(id: "test", title: "Test", category: "Verbs", priority: "Test", brief: "Test", scope: "Present", forms: ["ha"], requirements: [], target: 2, reviewedBooks: 1, demoExamples: 8)
        #expect(!topic.covered)
        #expect(topic.occurrences(in: "hablar hacer ha ¡Ha!") == [2])
        let complete = TopicRequest(id: "done", title: "Done", category: "Test", priority: "Test", brief: "Test", scope: "Test", forms: [], requirements: [], target: 2, reviewedBooks: 2, demoExamples: 0)
        #expect(complete.covered); #expect(complete.coverageLabel == "Covered")
    }
    @Test func legacyDraftStillDecodes() throws {
        let data = Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"title\":\"Mi historia\",\"spanish\":\"Hola\",\"status\":\"Draft\"}".utf8)
        let draft = try JSONDecoder().decode(Contribution.self, from: data)
        #expect(draft.topicID == nil); #expect(draft.teachingNote == nil)
    }
}
