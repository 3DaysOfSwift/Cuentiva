import Foundation
import CryptoKit
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
    func remove(_ id: UUID) { values.removeAll { $0.id == id } }
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
    var refreshCalls = 0
    func refresh() async { refreshCalls += 1 }
    func purchase() async throws { hasAccess = true }
    var restoresAccess = false
    var restoreFailure: AppFailure?
    func restore() async throws {
        if let restoreFailure { throw restoreFailure }
        if restoresAccess { hasAccess = true }
    }
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
    @Test func authorsUseStableIDsAndRespectLibraryAccess() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        var anaBook = sample("ana-book"); anaBook.authorID = "ana"
        let legacyBook = sample("legacy")
        let library = LibraryManager(repository: MemoryBooks(values: [anaBook, legacyBook]), purchases: purchases, progress: progress)
        try await library.load()
        let ana = Author.demoProfiles[0]
        #expect(library.authors.isEmpty)
        #expect(library.books(by: ana).isEmpty)
        purchases.hasAccess = true
        #expect(library.authors.map(\.id) == ["ana"])
        #expect(library.books(by: ana).map(\.id) == ["ana-book"])
        try await progress.recordEncounter(book: anaBook, sentence: anaBook.sentences[0])
        _ = try await progress.complete(book: anaBook)
        #expect(library.books(by: ana).count == 1)
        let oldData = try JSONEncoder().encode(legacyBook)
        #expect(try JSONDecoder().decode(Book.self, from: oldData).authorID == nil)
    }
    @Test func nextReadKeepsRecentReadingAndRecyclesAfterCompletion() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let first = sample("first"), second = sample("second")
        let library = LibraryManager(repository: MemoryBooks(values: [first, second]), purchases: purchases, progress: progress)
        try await library.load()
        #expect(library.nextRead == nil)
        purchases.hasAccess = true
        let initial = library.nextRead?.id
        #expect(initial != nil)
        try await progress.setLearningLevel(.c2)
        #expect(library.nextRead?.id == initial)
        try await progress.recordEncounter(book: second, sentence: second.sentences[0])
        #expect(library.nextRead?.id == second.id)
        _ = try await progress.complete(book: second)
        #expect(library.nextRead?.id == first.id)
        try await progress.recordEncounter(book: first, sentence: first.sentences[0])
        _ = try await progress.complete(book: first)
        #expect(library.nextRead != nil)
        #expect(library.revisiting)
        #expect(progress.snapshot.completed == [first.id, second.id])
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
        #expect(books.count == 52); #expect(Set(books.map(\.level)) == ["A1", "A2", "B1"])
        #expect(books.filter { $0.kind == .movieScript }.count == 3)
        #expect(books.filter { $0.kind == .story }.count == 46)
        #expect(books.filter { $0.kind == .verbs }.count == 3)
        let pattaya = StoryLocation(latitude: 12.9236, longitude: 100.8825, accuracy: 100, capturedAt: .now, placeName: "Pattaya")
        let seeded = books.filter { $0.isDemoLocation == true }
        #expect(seeded.count == 3)
        for book in seeded {
            let location = try #require(book.submissionLocation)
            #expect(location.valid)
            #expect(pattaya.kilometers(to: location) < 1609.344)
        }

        for book in books {
            if let glossary = book.matchGlossary {
                #expect(Set(glossary.keys) == Set(book.vocabulary.map(\.word)))
                #expect(glossary.values.allSatisfy { !$0.isEmpty })
            }
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

@Suite @MainActor struct NearbyTests {
    func place(_ longitude: Double = 115.26, date: Date = .now) -> StoryLocation {
        .init(latitude: -8.51, longitude: longitude, accuracy: 100, capturedAt: date, placeName: "Ubud, Indonesia")
    }
    @Test func distanceFilteringAndLegacyLibrary() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        var local = sample("bali"); local.submissionLocation = place()
        var distant = sample("far"); distant.submissionLocation = place(0)
        let library = LibraryManager(repository: MemoryBooks(values: [sample(), local, distant]), purchases: purchases, progress: progress)
        try await library.load()
        let nearby = NearbyManager(library: library, purchases: purchases)
        #expect(nearby.stories(around: place(), kilometers: 5).map(\.id) == ["bali"])
        #expect(nearby.stories(around: place(date: .now.addingTimeInterval(-600)), kilometers: 5).isEmpty)
        #expect(library.search("", level: nil, completedOnly: false).map(\.id) == ["cafe"])
        try await progress.recordEncounter(book: local, sentence: local.sentences[0])
        _ = try await progress.complete(book: local)
        #expect(library.search("", level: nil, completedOnly: true).map(\.id) == ["bali"])
        purchases.hasAccess = false
        #expect(nearby.stories(around: place(), kilometers: 100).isEmpty)
    }
    @Test func submittedPlaceCannotBeMovedOrRemoved() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let intro = sample(); try await progress.recordEncounter(book: intro, sentence: intro.sentences[0]); _ = try await progress.complete(book: intro)
        let storage = MemoryContributions()
        let feature = ContributionManager(repository: storage, purchases: purchases, progress: progress)
        var draft = Contribution(); draft.title = "Aquí"; draft.spanish = "Hoy veo una casa bonita y hablo con una amiga nueva."; draft.submissionLocation = place()
        try await feature.save(draft, submit: true)
        draft.submissionLocation = nil
        await #expect(throws: (any Error).self) { try await feature.save(draft, submit: false) }
        draft.submissionLocation = place(0)
        await #expect(throws: (any Error).self) { try await feature.save(draft, submit: true) }
        #expect(await storage.drafts().first?.submissionLocation?.longitude == 115.26)
        try await feature.remove(draft.id)
        #expect(await storage.drafts().isEmpty)
        var stale = Contribution(); stale.title = "Yesterday"; stale.spanish = draft.spanish; stale.submissionLocation = place(date: .now.addingTimeInterval(-600))
        await #expect(throws: (any Error).self) { try await feature.save(stale, submit: true) }
    }
}

@Suite @MainActor struct PracticeProgressTests {
    @Test func capturesBaselineAndAwardsOnceAcrossReload() async throws {
        let repo = MemoryProgress(), progress = ProgressManager(repository: MemoryProgress())
        let manager = ProgressManager(repository: repo); try await manager.load()
        let book = sample()
        try await manager.recordEncounter(book: book, sentence: book.sentences[0])
        #expect(manager.snapshot.bookWordBaselines?[book.id] == [])
        #expect(manager.snapshot.seenWords?.contains("café") == true)
        let receipt = try await manager.complete(book: book)
        #expect(receipt.streakCelebration == 1)
        #expect(try await manager.complete(book: book).streakCelebration == nil)
        #expect(try await manager.rewardPractice(book: book, matches: 1))
        let restored = ProgressManager(repository: repo); try await restored.load()
        #expect(try await restored.rewardPractice(book: book, matches: 1) == false)
        #expect(restored.snapshot.doubloons == 1)
        #expect(restored.snapshot.completed.count == 1)
        try await progress.load()
        await #expect(throws: (any Error).self) { try await progress.rewardPractice(book: book, matches: 1) }
    }
    @Test func failedRewardDoesNotMintCoin() async throws {
        let repo = MemoryProgress(), book = sample()
        let manager = ProgressManager(repository: repo); try await manager.load()
        try await manager.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await manager.complete(book: book)
        await repo.setFailure(true)
        await #expect(throws: (any Error).self) { try await manager.rewardPractice(book: book, matches: 1) }
        #expect(manager.snapshot.doubloons == nil)
        #expect(manager.snapshot.rewardedBooks == nil)
    }
    @Test func legacyProgressDoesNotInventBaseline() async throws {
        let repo = MemoryProgress()
        var old = LearnerProgress(); old.evidence = ["café": 1]
        try await repo.save(old)
        let manager = ProgressManager(repository: repo); try await manager.load()
        let book = sample(); try await manager.recordEncounter(book: book, sentence: book.sentences[0])
        #expect(manager.snapshot.bookWordBaselines?[book.id] == nil)
    }
}

@Suite @MainActor struct LanguageTermsTests {
    @Test func bilingualSearchAndRelatedEntriesStayNavigable() {
        let feature = LanguageTermsManager()
        let terms = feature.search("")
        #expect(terms.count == 12)
        #expect(Set(terms.map(\.id)).count == terms.count)
        #expect(feature.search(" SUSTANTIVO ").map(\.id) == ["noun"])
        #expect(feature.search("conjugacion").contains { $0.id == "conjugation" })
        #expect(feature.search("not-a-term").isEmpty)
        for term in terms {
            #expect(!term.meaning.isEmpty && !term.englishExample.isEmpty && !term.spanishExample.isEmpty)
            #expect(term.related.allSatisfy { $0 != term.id && feature.term($0) != nil })
        }
    }
}

@Suite @MainActor struct LearningLevelTests {
    @Test func selectedLevelPersistsAndFailedSaveLeavesItUnchanged() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        #expect(progress.snapshot.selectedLearningLevel == nil)
        try await progress.setLearningLevel(.b2)
        let reloaded = ProgressManager(repository: repository)
        try await reloaded.load()
        #expect(reloaded.snapshot.selectedLearningLevel == .b2)
        #expect(reloaded.snapshot.vocabulary.isEmpty)
        await repository.setFailure(true)
        do { try await progress.setLearningLevel(.c2); Issue.record("Expected save failure") } catch {}
        #expect(progress.snapshot.selectedLearningLevel == .b2)
        await repository.setFailure(false)
        try await progress.reset()
        #expect(progress.snapshot.selectedLearningLevel == nil)
    }
    @Test func oldProgressWithoutLevelStillDecodes() throws {
        let encoded = try JSONEncoder().encode(LearnerProgress())
        var fields = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        fields.removeValue(forKey: "selectedLearningLevel")
        let oldData = try JSONSerialization.data(withJSONObject: fields)
        let decoded = try JSONDecoder().decode(LearnerProgress.self, from: oldData)
        #expect(decoded.selectedLearningLevel == nil)
    }
}

actor TestCatalogueTransport: CatalogueTransport {
    var manifest: CatalogueManifest
    var payloads: [String: Data] = [:]
    var broken = false
    var partReads = 0
    var failID: String?
    init(_ books: [Book], author: Author = Author.demoProfiles[0]) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        var refs: [PackDescriptor] = []
        for (i, value) in books.enumerated() {
            var book = value; book.authorID = author.id
            let id = "pack-\(i)"
            let payload = try encoder.encode(LibraryPack(schema: 2, id: id, authors: [author], books: [book]))
            let checksum = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
            refs.append(PackDescriptor(id: id, checksum: checksum, bytes: payload.count, books: 1))
            payloads[id] = payload
        }
        manifest = CatalogueManifest(schema: 2, version: String(repeating: "a", count: 64), packs: refs)
    }
    func fail() { broken = true }
    func failOnly(_ id: String?) { failID = id }
    func corrupt(_ id: String) { payloads[id] = Data("broken".utf8) }
    func fetch(pack: PackDescriptor?) throws -> Data {
        guard let pack else { return try JSONEncoder().encode(manifest) }
        partReads += 1
        if broken || failID == pack.id { throw AppFailure.unavailable("Offline") }
        return payloads[pack.id]!
    }
}
@Suite struct CatalogueSyncTests {
    @Test func replacesBundleWithoutDuplicatesAndCachesOffline() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appending(path: "catalogue.json")
        let source = MemoryBooks(values: [sample(), sample("old")])
        let transport = try TestCatalogueTransport([sample(), sample("new")])
        let repository = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache)
        #expect(try await repository.books().map(\.id) == ["cafe", "old"])
        #expect(try await repository.sync().map(\.id) == ["cafe", "new"])
        let reads = await transport.partReads
        _ = try await repository.sync()
        #expect(await transport.partReads == reads)
        let reloaded = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache)
        #expect(try await reloaded.books().map(\.id) == ["cafe", "new"])
        #expect(await reloaded.authors() == [Author.demoProfiles[0]])
        let failing = try TestCatalogueTransport([sample(), sample("later")]); await failing.fail()
        let offline = SyncedBookRepository(bundled: source, transport: failing, cacheURL: cache)
        await #expect(throws: AppFailure.self) { try await offline.sync() }
        #expect(try await offline.books().map(\.id) == ["cafe", "new"])
    }
    @Test func onlyChangedRevisionDownloadsAndInterruptedSyncResumes() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appending(path: "catalogue.json"), source = MemoryBooks(values: [sample()])
        let a = try TestCatalogueTransport([sample(), sample("old")])
        _ = try await SyncedBookRepository(bundled: source, transport: a, cacheURL: cache).sync()
        let b = try TestCatalogueTransport([sample(), sample("new"), sample("third")])
        await b.failOnly("pack-2")
        let repo = SyncedBookRepository(bundled: source, transport: b, cacheURL: cache)
        await #expect(throws: AppFailure.self) { try await repo.sync() }
        #expect(try await repo.books().map(\.id) == ["cafe", "old"])
        #expect(await b.partReads == 2) // unchanged pack reused; second download fails
        await b.failOnly(nil)
        #expect(try await repo.sync().map(\.id) == ["cafe", "new", "third"])
        #expect(await b.partReads == 3) // successful new pack reused after the interruption
    }
    @Test func invalidCatalogueCannotReplaceBundledBooks() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = MemoryBooks(values: [sample()])
        for books in [[sample(),sample()], [sample("missing-intro")]] {
            let transport = try TestCatalogueTransport(books)
            let repository = SyncedBookRepository(bundled: source, transport: transport, cacheURL: directory.appending(path: UUID().uuidString + "/catalogue.json"))
            await #expect(throws: AppFailure.self) { try await repository.sync() }
            #expect(try await repository.books().count == 1)
        }
        let transport = try TestCatalogueTransport([sample()]); await transport.corrupt("pack-0")
        let repo = SyncedBookRepository(bundled: source, transport: transport, cacheURL: directory.appending(path: "bad/catalogue.json"))
        await #expect(throws: AppFailure.self) { try await repo.sync() }
    }
    @Test func authorOnlyRevisionUpdatesAlongsideBooks() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appending(path: "catalogue.json"), source = MemoryBooks(values: [sample()])
        let a = try TestCatalogueTransport([sample()])
        _ = try await SyncedBookRepository(bundled: source, transport: a, cacheURL: cache).sync()
        let author = Author(id: "ana", name: "Ana", portrait: "", introduction: "New introduction", note: "New note")
        let b = try TestCatalogueTransport([sample()], author: author)
        let repo = SyncedBookRepository(bundled: source, transport: b, cacheURL: cache)
        _ = try await repo.sync()
        #expect(await b.partReads == 1)
        #expect(await repo.authors() == [author])
    }
}

@Suite struct WeeklyAuthorTests {
    @Test func legacyProfilesResolveToPermanentCharactersWithoutChangingIdentity() {
        let legacy = Author(id: "ana", name: "Ana · demo narrator", portrait: "AuthorAna", introduction: "Old biography", note: "Old note")
        #expect(legacy.storyteller.id == legacy.id)
        #expect(legacy.storyteller.name == "Brasa")
        #expect(legacy.storyteller.portrait == "StorytellerBrasa")
        #expect(Set(Author.demoProfiles.map(\.portrait)).count == Author.demoProfiles.count)
        #expect(Author.demoProfiles.allSatisfy { $0.name.split(whereSeparator: { $0.isWhitespace }).count == 1 })
        var book = sample()
        book.authorID = legacy.id
        #expect(book.storytellerName == "Brasa")
        #expect(Author.supportedPortraits.contains("AuthorAna"))
        #expect(!Author.supportedPortraits.contains("https://example.com/portrait.jpg"))
    }
    @Test func stableWithinWeekAndRotatesAcrossMondayWithoutDependingOnInputOrder() {
        let monday = Date(timeIntervalSince1970: 345_600 + 2900 * 604_800)
        let authors = Author.demoProfiles
        let current = Author.weeklyOrder(authors, on: monday)
        #expect(current == Author.weeklyOrder(authors.reversed(), on: monday.addingTimeInterval(604_799)))
        let next = Author.weeklyOrder(authors, on: monday.addingTimeInterval(604_800))
        #expect(current.first?.id != next.first?.id)
        #expect(Set(current.map(\.id)) == Set(next.map(\.id)))
        #expect(Author.weeklyOrder([], on: monday).isEmpty)
        #expect(Author.weeklyOrder([authors[0]], on: monday) == [authors[0]])
    }
}

@MainActor @Suite struct FreshLibraryTests {
    final class Clock { var date = Date(timeIntervalSince1970: 1_800_014_400) }
    @Test func dailySelectionRetainsCompletedBooksAcrossRelaunchAndRenewsTomorrow() async throws {
        let clock = Clock(), store = MemoryProgress(), purchases = TestPurchases()
        purchases.hasAccess = true
        let progress = ProgressManager(repository: store, now: { clock.date })
        let books = (0..<6).map { sample("daily-\($0)") }
        let source = MemoryBooks(values: books)
        let library = LibraryManager(repository: source, purchases: purchases, progress: progress, now: { clock.date })
        try await library.load()
        try await library.prepareDailyReads()
        let original = library.dailyReads
        for book in original {
            try await progress.recordEncounter(book: book, sentence: book.sentences[0])
            _ = try await progress.complete(book: book)
            #expect(library.dailyReads.map(\.id) == original.map(\.id))
            #expect(library.nextRead?.id == (original.first { !progress.snapshot.completed.contains($0.id) } ?? original[0]).id)
        }
        let reloadedProgress = ProgressManager(repository: store, now: { clock.date })
        let reloaded = LibraryManager(repository: source, purchases: purchases, progress: reloadedProgress, now: { clock.date })
        try await reloaded.load(); try await reloaded.prepareDailyReads()
        #expect(reloaded.dailyReads.map(\.id) == original.map(\.id))
        clock.date = Calendar.current.date(byAdding: .day, value: 1, to: clock.date)!
        try await reloaded.prepareDailyReads()
        #expect(Set(reloaded.dailyReads.map(\.id)).isDisjoint(with: Set(original.map(\.id))))
        #expect(reloadedProgress.snapshot.completed.count == 3)
    }
    @Test func newArrivalsLeadAndOldAttemptsRestWithoutLosingProgress() async throws {
        let clock = Clock(), store = MemoryProgress(), purchases = TestPurchases(); purchases.hasAccess = true
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let progress = ProgressManager(repository: store, now: { clock.date }, calendar: calendar)
        let old = sample("old"), ongoing = sample("ongoing"), fresh = sample("fresh")
        let first = LibraryManager(repository: MemoryBooks(values: [old, ongoing]), purchases: purchases, progress: progress, now: { clock.date }, calendar: calendar)
        try await first.load()
        try await progress.recordEncounter(book: old, sentence: old.sentences[0])
        let arrival = progress.snapshot.bookArrivals?[old.id]
        clock.date = calendar.date(byAdding: .day, value: 40, to: clock.date)!
        try await progress.recordEncounter(book: ongoing, sentence: ongoing.sentences[0])
        let updated = LibraryManager(repository: MemoryBooks(values: [old, ongoing, fresh]), purchases: purchases, progress: progress, now: { clock.date }, calendar: calendar)
        try await updated.load()
        #expect(updated.nextRead?.id == fresh.id)
        #expect(updated.dailyReads.map(\.id).contains(ongoing.id))
        #expect(!updated.dailyReads.map(\.id).contains(old.id))
        #expect(updated.search("", level: nil, completedOnly: false).count == 3)
        #expect(progress.snapshot.bookArrivals?[old.id] == arrival)
        clock.date = calendar.date(byAdding: .day, value: 3, to: clock.date)!
        #expect(updated.dailyReads.map(\.id).contains(ongoing.id))
        clock.date = calendar.date(byAdding: .day, value: 1, to: clock.date)!
        #expect(!updated.dailyReads.map(\.id).contains(ongoing.id))
        #expect(!progress.snapshot.attempts[old.id, default: []].isEmpty)
        let reloaded = ProgressManager(repository: store); try await reloaded.load()
        #expect(reloaded.snapshot.bookArrivals == progress.snapshot.bookArrivals)
        #expect(reloaded.snapshot.bookLastRead == progress.snapshot.bookLastRead)
    }
    @Test func dailyThreeAreStableThenRotateWithoutNewDownloads() async throws {
        let clock = Clock(), purchases = TestPurchases(); purchases.hasAccess = true
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let progress = ProgressManager(repository: MemoryProgress(), now: { clock.date }, calendar: calendar)
        let books = (0..<6).map { sample("book-\($0)") }
        let library = LibraryManager(repository: MemoryBooks(values: books), purchases: purchases, progress: progress, now: { clock.date }, calendar: calendar)
        try await library.load()
        clock.date = calendar.date(byAdding: .year, value: 1, to: clock.date)!
        let today = Set(library.dailyReads.map(\.id))
        #expect(today.count == 3)
        #expect(today == Set(library.dailyReads.map(\.id)))
        clock.date = calendar.date(byAdding: .day, value: 1, to: clock.date)!
        #expect(today.isDisjoint(with: Set(library.dailyReads.map(\.id))))
        #expect(!library.revisiting)
    }
    @Test func restingExhaustionRecyclesWithoutResettingAnything() async throws {
        let clock = Clock(), purchases = TestPurchases(); purchases.hasAccess = true
        let store = MemoryProgress(), progress = ProgressManager(repository: store, now: { clock.date })
        let book = sample()
        let library = LibraryManager(repository: MemoryBooks(values: [book]), purchases: purchases, progress: progress, now: { clock.date })
        try await library.load(); try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        try await progress.setVocabulary("café", state: .known)
        let before = try JSONEncoder().encode(progress.snapshot)
        #expect(library.revisiting)
        #expect(library.dailyReads.map(\.id) == [book.id])
        #expect(progress.snapshot.completed == [book.id])
        #expect(progress.snapshot.vocabulary["café"] == .known)
        // Viewing recommendations performs no persistence writes or reset.
        #expect(try JSONDecoder().decode(LearnerProgress.self, from: before).practiceDays == progress.snapshot.practiceDays)
        purchases.hasAccess = false; #expect(library.dailyReads.isEmpty)
    }
}

actor FantasyTestRepository: FantasyRepository {
    var archive = FantasyArchive()
    var fail = false
    func load() -> FantasyArchive { archive }
    func save(_ value: FantasyArchive) throws {
        if fail { throw AppFailure.unavailable("Save failed") }
        archive = value
    }
    func setFailure() { fail = true }
}
struct FantasyTestGenerator: FantasyGenerator {
    var invalid = false
    func identity(name: String, biography: String, creature: FantasyCreature) async throws -> FantasyIdentity {
        .init(name: invalid ? "Two Names" : "Lirio", biography: "A turtle who dances beside the sea.")
    }
    func story(memory: String, profile: FantasyProfile) async throws -> FantasyStory {
        .init(title: "La fiesta", englishTitle: "The festival", sentences: (0..<16).map { _ in .init(spanish: "La tortuga baila.", english: "The turtle dances.") })
    }
}
@Suite @MainActor struct FantasyTests {
    @Test func skippedIntroductionPersistsWithoutFakeIdentity() async throws {
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        try await feature.load()
        #expect(!feature.introductionSeen)
        try await feature.finishIntroduction()
        let relaunched = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        try await relaunched.load()
        #expect(relaunched.introductionSeen)
        #expect(relaunched.profile == nil)
    }
    @Test func invalidStoryPairsAreRejected() {
        let invalid = FantasyStory(title: "Hola", englishTitle: "Hello", sentences: [.init(spanish: "Hola", english: "")])
        #expect(throws: (any Error).self) { try FantasyValidation.story(invalid) }
    }

    @Test func creatureSurvivesRelaunchAndStoriesStayPrivate() async throws {
        let repository = FantasyTestRepository()
        let first = FantasyManager(repository: repository, generator: FantasyTestGenerator(), draw: { .turtle })
        try await first.load()
        #expect(try await first.drawCreature() == .turtle)
        let revealNumber = try #require(first.profile?.revealNumber)
        #expect((1...999).contains(revealNumber))
        #expect((revealNumber - 1) % FantasyCreature.allCases.count == 0)
        let next = FantasyManager(repository: repository, generator: FantasyTestGenerator(), draw: { .fox })
        try await next.load()
        #expect(try await next.drawCreature() == .turtle)
        #expect(next.profile?.revealNumber == revealNumber)
        try await next.createIdentity(name: "Matthew", biography: "I travel and build apps.")
        let story = try await next.createStory(memory: "I danced in Mexico.")
        #expect(next.profile?.identity?.name == "Lirio")
        #expect(next.stories.map(\.id) == [story.id])
    }
    @Test func failedSaveDoesNotRevealUnpersistedCreature() async throws {
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        try await feature.load(); await repository.setFailure()
        await #expect(throws: (any Error).self) { _ = try await feature.drawCreature() }
        #expect(feature.profile == nil)
    }
    @Test func malformedIdentityDoesNotReplaceProfile() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator(invalid: true))
        try await feature.load(); _ = try await feature.drawCreature()
        await #expect(throws: (any Error).self) { try await feature.createIdentity(name: "Matt", biography: "A traveller") }
        #expect(feature.profile?.identity == nil)
        #expect(feature.profile?.creature != nil)
    }
}

private struct UnavailableFantasyGenerator: FantasyGenerator {
    func availabilityMessage() async -> String? { "Apple Intelligence is unavailable." }
    func identity(name: String, biography: String, creature: FantasyCreature) async throws -> FantasyIdentity { throw AppFailure.unavailable("No AI available") }
    func story(memory: String, profile: FantasyProfile) async throws -> FantasyStory { throw AppFailure.unavailable("No AI available") }
}
@Suite @MainActor struct StorytellerDetailsTests {
    @Test func saveAndReopenBioWithoutAI() async throws {
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: UnavailableFantasyGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        await feature.refreshAvailability()
        #expect(feature.availabilityMessage != nil)
        try await feature.saveDetails(name: " James ", biography: " A traveller who helps others. ")
        let reopened = FantasyManager(repository: repository, generator: UnavailableFantasyGenerator())
        try await reopened.load()
        #expect(reopened.profile?.details?.name == "James")
        #expect(reopened.profile?.details?.biography == "A traveller who helps others.")
        #expect(reopened.profile?.identity == nil)
        #expect(reopened.profile?.revealNumber == feature.profile?.revealNumber)
    }
    @Test func saveFailureKeepsPreviousBio() async throws {
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: UnavailableFantasyGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        try await feature.saveDetails(name: "James", biography: "The original bio.")
        await repository.setFailure()
        await #expect(throws: (any Error).self) { try await feature.saveDetails(name: "James", biography: "A replacement.") }
        #expect(feature.profile?.details?.biography == "The original bio.")
    }
    @Test func generationFailureDoesNotEraseSavedBio() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: UnavailableFantasyGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        try await feature.saveDetails(name: "James", biography: "A traveller.")
        await #expect(throws: (any Error).self) { try await feature.createIdentity(name: "James", biography: "A traveller.") }
        #expect(feature.profile?.details?.biography == "A traveller.")
    }
}

@Suite @MainActor struct LaunchAccessTests {
    @Test func catalogueCanDisplayWhilePaidLessonsRemainLocked() async throws {
        let purchases = TestPurchases(); purchases.checking = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: [sample(), sample("paid")]), purchases: purchases, progress: progress)
        try await library.load()
        #expect(!library.dailyReads.isEmpty)
        #expect(library.search("", level: nil, completedOnly: false).count == 2)
        let learning = LearningManager(purchases: purchases, progress: progress)
        #expect(!learning.canRead(sample("paid")))
        try await library.prepareDailyReads()
        #expect(progress.snapshot.dailyReadingIDs == nil)
        purchases.checking = false
        #expect(library.dailyReads.isEmpty)
        purchases.hasAccess = true
        try await library.prepareDailyReads()
        #expect(progress.snapshot.dailyReadingIDs?.count == 2)
    }
}

@Suite @MainActor struct ChatProductConfigurationTests {
    @Test func chatIsOneTimeUKPurchaseWithoutChangingLibraryConfiguration() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Cuentiva/3 - App Resources")
        let chat = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appending(path: "StorytellerChat.storekit"))) as? [String: Any])
        let settings = try #require(chat["settings"] as? [String: Any])
        #expect(settings["_storefront"] as? String == "GBR")
        let products = try #require(chat["products"] as? [[String: Any]])
        let product = try #require(products.first { $0["productID"] as? String == PurchaseManager.storytellerChatProductID })
        #expect(product["type"] as? String == "NonConsumable")
        #expect(product["displayPrice"] as? String == "24.99")
    }
}
