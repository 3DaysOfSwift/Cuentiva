import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

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
        await #expect(throws: AppFailure.self) { try await library.load() }
        let ana = Author.demoProfiles[0]
        #expect(await library.authors.isEmpty)
        #expect(await library.books(by: ana).isEmpty)
        purchases.hasAccess = true
        try await library.load()
        #expect(await library.authors.map(\.id) == ["ana"])
        #expect(await library.books(by: ana).map(\.id) == ["ana-book"])
        try await progress.recordEncounter(book: anaBook, sentence: anaBook.sentences[0])
        _ = try await progress.complete(book: anaBook)
        #expect(await library.books(by: ana).count == 1)
        let oldData = try JSONEncoder().encode(legacyBook)
        #expect(try JSONDecoder().decode(Book.self, from: oldData).authorID == nil)
    }
    @Test func nextReadKeepsRecentReadingAndRecyclesAfterCompletion() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let first = sample("first"), second = sample("second")
        let library = LibraryManager(repository: MemoryBooks(values: [first, second]), purchases: purchases, progress: progress)
        await #expect(throws: AppFailure.self) { try await library.load() }
        #expect(await library.nextRead == nil)
        purchases.hasAccess = true
        try await library.load()
        let initial = await library.nextRead?.id
        #expect(initial != nil)
        try await progress.setLearningLevel(.c2)
        #expect(await library.nextRead?.id == initial)
        try await progress.recordEncounter(book: second, sentence: second.sentences[0])
        #expect(await library.nextRead?.id == second.id)
        _ = try await progress.complete(book: second)
        #expect(await library.nextRead?.id == first.id)
        try await progress.recordEncounter(book: first, sentence: first.sentences[0])
        _ = try await progress.complete(book: first)
        #expect(await library.nextRead != nil)
        #expect(await library.revisiting)
        #expect(progress.snapshot.completed == [first.id, second.id])
    }
    @Test func librarySearchAndCompletedCollectionAreGated() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress()), book = sample(); try await progress.load()
        let library = LibraryManager(repository: MemoryBooks(values: [book]), purchases: purchases, progress: progress); await #expect(throws: AppFailure.self) { try await library.load() }
        #expect(await library.search("", level: nil, completedOnly: false).isEmpty)
        purchases.hasAccess = true
        try await library.load()
        #expect(await library.search("cafe", level: "A1", completedOnly: false).count == 1)
        #expect(await library.search("", level: "B1", completedOnly: false).isEmpty)
        #expect(await library.search("", level: nil, completedOnly: true).isEmpty)
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        #expect(await library.search("", level: nil, completedOnly: true).count == 1)
    }
    @Test func formatsCombineWithSearchLevelCompletionAndAccess() async throws {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let story = sample("story")
        var script = sample("script"); script.format = .movieScript; script.scene = "A café"
        let library = LibraryManager(repository: MemoryBooks(values: [story, script]), purchases: purchases, progress: progress)
        await #expect(throws: AppFailure.self) { try await library.load() }
        #expect(await library.search("", level: nil, completedOnly: false, format: .movieScript, sort: .title).isEmpty)
        purchases.hasAccess = true
        try await library.load()
        #expect(await library.search("cafe", level: "A1", completedOnly: false, format: .movieScript, sort: .title).map(\.id) == ["script"])
        #expect(await library.search("cafe", level: "B1", completedOnly: false, format: .movieScript, sort: .title).isEmpty)
        #expect(await library.search("", level: nil, completedOnly: false, format: .story, sort: .library).map(\.id) == ["story"])
        #expect(await library.search("", level: nil, completedOnly: false, format: nil, sort: .type).map(\.id) == ["script", "story"])
        // Equal titles/difficulty use the stable ID tie-breaker.
        for sort in [BookSort.title, .difficulty] {
            #expect(await library.search("", level: nil, completedOnly: false, format: nil, sort: sort).map(\.id) == ["script", "story"])
        }
        #expect(await library.search("", level: nil, completedOnly: true, format: .movieScript, sort: .title).isEmpty)
        try await progress.recordEncounter(book: script, sentence: script.sentences[0])
        _ = try await progress.complete(book: script)
        #expect(await library.search("", level: nil, completedOnly: true, format: .movieScript, sort: .title).map(\.id) == ["script"])
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
        #expect(await library.search("cafe", level: "A1", completedOnly: false, format: .verbs, sort: .title).map(\.id) == ["verb"])
        #expect(await library.search("", level: nil, completedOnly: true, format: .verbs, sort: .type).isEmpty)
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
        #if canImport(CuentivaAppModel)
        let root = TestResources.repositoryRoot
        let url = root.appending(path: "Cuentiva/3 - App Resources/Library.dat")
        #else
        let url = try #require(Bundle.main.url(forResource: "Library", withExtension: "dat"))
        #endif
        let books = try await BundledBookRepository(url: url).books()
        let introduction = try #require(books.first { $0.id == "cafe" })
        #expect(introduction.storyteller == Author.pipa)
        #expect(introduction.author == "Pipa")
        #expect(books.count == 52); #expect(Set(books.map(\.level)) == ["A1", "A2", "B1"])
        #expect(books.filter { $0.kind == .movieScript }.count == 3)
        #expect(books.filter { $0.kind == .story }.count == 46)
        #expect(books.filter { $0.kind == .verbs }.count == 3)
        // These are fictional travel stories, not location submissions.
        #expect(books.allSatisfy { $0.isDemoLocation == nil && $0.submissionLocation == nil })

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
                for half in [book.sentences, book.continuation ?? [], book.ending ?? []] {
                    let tokens = half.flatMap { WordComparison.words($0.spanish).map(WordComparison.normalized) }
                    for form in focus.forms { #expect(tokens.contains(form)) }
                }
                for form in focus.forms { #expect(book.vocabulary.first { $0.word == form }?.lemma == focus.infinitive) }
            }
            if book.kind == .movieScript {
                #expect(book.scene?.isEmpty == false)
                #expect(book.cast.count >= 2)
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
