import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct BinaryLibraryTests {
    private func resource(_ name: String) throws -> URL {
        #if canImport(CuentivaAppModel)
        return TestResources.repositoryRoot.appending(path: "Cuentiva/3 - App Resources/" + name)
        #else
        let bundle = name == "Books.json" ? Bundle(for: BinaryLibraryFixtureBundle.self) : Bundle.main
        return try #require(bundle.url(forResource: name, withExtension: nil))
        #endif
    }

    @Test func allRealBooksRoundTripWithoutLosingAnyFields() throws {
        let expected = try JSONDecoder().decode([Book].self, from: Data(contentsOf: (try resource("Books.json"))))
        let library = try BinaryLibrary(url: (try resource("Library.dat")))
        #expect(library.count == 52)
        #expect(try library.books() == expected)
        let encoded = try BinaryLibrary.encode(expected)
        #expect(try BinaryLibrary(data: encoded).books() == expected)
        #expect(encoded == (try Data(contentsOf: resource("Library.dat"))))
        #expect(try library.book(at: 51) == expected[51])
        #expect(throws: AppFailure.self) { try library.book(at: -1) }
        #expect(throws: AppFailure.self) { try library.book(at: 52) }
    }

    @Test func downloadedWriterPreservesOptionalMetadataAndRejectsInvalidIntegers() throws {
        var book = sample()
        book.authorID = "fantasy"
        book.personalAuthor = Author(id: "fantasy", name: "Luz", portrait: "fox",
            introduction: "¡Hola! 🦊", note: "A personal storyteller")
        book.matchGlossary = ["árbol": "tree", "café": "coffee"]
        book.isDemoLocation = false
        book.submissionLocation = StoryLocation(latitude: 1, longitude: 2, accuracy: 3,
            capturedAt: Date(timeIntervalSinceReferenceDate: 1234), placeName: "México")
        book.format = .movieScript
        book.scene = "A forest"
        book.continuation = []
        book.verbFocus = VerbFocus(infinitive: "ser", tense: "present", forms: ["soy", "eres"], scope: "Test")
        #expect(try BinaryLibrary(data: BinaryLibrary.encode([book])).books() == [book])
        book.continuation = [.init(id: "last", spanish: "¡Hasta mañana!", english: "See you tomorrow!", speaker: "Luz")]
        #expect(try BinaryLibrary(data: BinaryLibrary.encode([book])).books() == [book])
        #expect(throws: AppFailure.self) { try BinaryLibrary.encode([]) }
        let invalid = Book(id: "bad", title: "Bad", englishTitle: "Bad", author: "Test", level: "A1",
            symbol: "book", palette: -1, summary: "", sentences: [], vocabulary: [], license: "Test")
        #expect(throws: AppFailure.self) { try BinaryLibrary.encode([invalid]) }
    }

    @Test func editorialLibraryHasThreeChaptersWithAnUnchangedTwoChapterReader() throws {
        let books = try BinaryLibrary(url: resource("Library.dat")).books()
        var allSentenceIDs: Set<String> = []
        for book in books {
            let middle = try #require(book.continuation)
            let ending = try #require(book.ending)
            #expect(book.editorialRevision == 3)
            #expect(book.sentences.count >= 4 && middle.count >= 4 && ending.count >= 4)
            #expect(book.fullText == book.sentences + middle)
            #expect(book.completeText == book.fullText + ending)
            #expect(Author.demoProfiles.contains { $0.id == book.authorID && $0.name == book.author })
            for sentence in book.completeText {
                #expect(allSentenceIDs.insert(sentence.id).inserted)
                #expect(!sentence.spanish.isEmpty && !sentence.english.isEmpty)
                if book.kind == .movieScript { #expect(sentence.speaker != nil) }
            }
            let words = book.fullText.flatMap { WordComparison.words($0.spanish).map(WordComparison.normalized) }
            let counts = Dictionary(grouping: words, by: { $0 }).mapValues(\.count)
            #expect(Set(counts.keys) == Set(book.vocabulary.map(\.word)))
            for entry in book.vocabulary { #expect(counts[entry.word] == entry.occurrences) }
            if let focus = book.verbFocus { #expect(Set(focus.forms).isSubset(of: Set(words))) }
            let glossary = try #require(book.matchGlossary)
            #expect(Set(glossary.keys) == Set(words))
            #expect(glossary.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }
        #expect(Set(books.map(\.authorID)).count == 9)
        #expect(books.filter { $0.kind == .movieScript }.count == 3)
        #expect(books.filter { $0.kind == .verbs }.count == 3)
    }

    @Test func legacyVersionOneRemainsReadableAndEndingOffsetsAreValidated() throws {
        let book = sample()
        var legacy = try BinaryLibrary.encode([book])
        // A v1 single-record file: the first 140 bytes are the old record.
        // Unreferenced padding before its strings is legal; offsets stay absolute.
        legacy[8] = 1
        #expect(try BinaryLibrary(data: legacy).books() == [book])
        var revised = book
        revised.ending = [.init(id: "ending", spanish: "Fin.", english: "The end.")]
        revised.editorialRevision = 2
        let valid = try BinaryLibrary.encode([revised])
        #expect(try BinaryLibrary(data: valid).books() == [revised])
        var bad = valid
        bad.replaceSubrange(156..<160, with: [0xfe, 0xff, 0xff, 0xff])
        #expect(throws: AppFailure.self) { try BinaryLibrary(data: bad).books() }
        bad = valid
        bad.replaceSubrange(160..<164, with: [0xff, 0xff, 0xff, 0xff])
        #expect(throws: AppFailure.self) { try BinaryLibrary(data: bad).books() }
        revised.ending = []
        #expect(try BinaryLibrary(data: BinaryLibrary.encode([revised])).books() == [revised])
        revised.editorialRevision = -1
        #expect(throws: AppFailure.self) { try BinaryLibrary.encode([revised]) }
        revised.editorialRevision = Int(UInt32.max)
        #expect(throws: AppFailure.self) { try BinaryLibrary.encode([revised]) }
    }

    @Test func introductionWorksWithoutFullLibraryFile() async throws {
        let repository = BundledBookRepository(url: nil, introductionURL: (try resource("Introduction.dat")))
        let book = try await repository.introduction()
        let library = try BinaryLibrary(url: (try resource("Library.dat")))
        #expect(book == (try library.book(at: 0)))
        #expect(book.id == "cafe")
        await #expect(throws: AppFailure.self) { try await repository.books() }
    }

    @Test func invalidHeadersOffsetsAndTextThrowInsteadOfAccessingInvalidMemory() throws {
        let valid = try Data(contentsOf: (try resource("Library.dat")))
        for length in [0, 7, 15, 16, 100] {
            #expect(throws: AppFailure.self) { try BinaryLibrary(data: Data(valid.prefix(length))) }
        }
        var version = valid; version[8] = 99
        #expect(throws: AppFailure.self) { try BinaryLibrary(data: version) }
        // Make the first title's offset point outside the file.
        var offset = valid; offset.replaceSubrange(24..<28, with: [0xfe, 0xff, 0xff, 0xff])
        #expect(throws: AppFailure.self) { try BinaryLibrary(data: offset).book(at: 0) }
        var text = valid
        let titleOffset = valid.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 24, as: UInt32.self)) }
        text[Int(titleOffset)] = 0xff
        #expect(throws: AppFailure.self) { try BinaryLibrary(data: text).book(at: 0) }
        var count = valid; count.replaceSubrange(116..<120, with: [0xff, 0xff, 0xff, 0xff])
        #expect(throws: AppFailure.self) { try BinaryLibrary(data: count).book(at: 0) }
    }

    @Test func realLibraryLoadsWithoutOpeningOrWritingAnyDatabase() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = directory.appending(path: "app.store")
        let store = SwiftDataStore(url: database)
        let bundle = BundledBookRepository(url: (try resource("Library.dat")))
        let repository = SyncedBookRepository(bundled: bundle, transport: try TestCatalogueTransport([sample()]),
            cacheURL: directory.appending(path: "catalogue.json"), store: store)
        let started = ContinuousClock.now
        let books = try await repository.books()
        print("Actual 52-book DAT display load: \(started.duration(to: .now))")
        #expect(books.count == 52)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func freshProgressIsReadOnlyAndFirstSaveSurvivesReopening() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let url = directory.appending(path: "progress.json")
        let repository = LocalProgressRepository(url: url, store: store)
        var progress = try await repository.load()
        #expect(progress.completed.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        progress.completed.insert("cafe")
        #if DEBUG
        try await store.failNextCommitForTesting()
        await #expect(throws: (any Error).self) { try await repository.save(progress) }
        #expect(try await store.read("progress") == nil)
        #endif
        try await repository.save(progress)
        let reopened = LocalProgressRepository(url: url, store: store)
        #expect(try await reopened.load() == progress)
    }

    @Test func openingOlderSessionNeverOverwritesDownloadedSnapshot() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let transport = try TestCatalogueTransport([sample(), sample("new")])
        let cache = directory.appending(path: "catalogue.json")
        let first = SyncedBookRepository(bundled: MemoryBooks(values: [sample()]), transport: transport, cacheURL: cache, store: store)
        let second = SyncedBookRepository(bundled: MemoryBooks(values: [sample()]), transport: transport, cacheURL: cache, store: store)
        _ = try await first.books()
        _ = try await second.sync()
        #expect(try await first.books() == [sample()])
        let next = SyncedBookRepository(bundled: MemoryBooks(values: []), transport: transport, cacheURL: cache, store: store)
        #expect(try await next.books().map(\.id) == ["cafe", "new"])
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "app.store").path))
    }

}

#if !canImport(CuentivaAppModel)
private final class BinaryLibraryFixtureBundle: NSObject {}
#endif
