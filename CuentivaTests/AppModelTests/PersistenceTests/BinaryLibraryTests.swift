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
        #expect(try library.book(at: 51) == expected[51])
        #expect(throws: AppFailure.self) { try library.book(at: -1) }
        #expect(throws: AppFailure.self) { try library.book(at: 52) }
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

    @Test func realLibraryPersistsAndReloadsWithSeparatePhaseTimings() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let bundle = BundledBookRepository(url: (try resource("Library.dat")))
        let transport = try TestCatalogueTransport([sample()])
        let repository = SyncedBookRepository(bundled: bundle, transport: transport,
            cacheURL: directory.appending(path: "catalogue.json"), store: store)
        let clock = ContinuousClock()
        let started = clock.now
        let books = try await repository.books()
        let displayed = clock.now
        #expect(books.count == 52)
        #expect(try await store.read("catalogue") == nil)
        let importing = clock.now
        try await repository.prepareStorage()
        let imported = clock.now
        let reopened = SyncedBookRepository(bundled: MemoryBooks(values: []), transport: transport,
            cacheURL: directory.appending(path: "catalogue.json"), store: store)
        #expect(try await reopened.books() == books)
        print("Actual 52-book phases: database open + DAT load \(started.duration(to: displayed)); import \(importing.duration(to: imported)); stored catalogue read \(imported.duration(to: clock.now))")
    }

    @Test func firstDisplayDoesNotWaitForCatalogueCommitAndImportCanRetry() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let repository = SyncedBookRepository(bundled: MemoryBooks(values: [sample()]),
            transport: try TestCatalogueTransport([sample()]), cacheURL: directory.appending(path: "catalogue.json"), store: store)
        #expect(try await repository.books() == [sample()])
        #expect(try await store.read("catalogue") == nil)
        #if DEBUG
        try await store.failNextCommitForTesting()
        await #expect(throws: (any Error).self) { try await repository.prepareStorage() }
        #expect(try await repository.books() == [sample()])
        #expect(try await store.read("catalogue") == nil)
        #endif
        try await repository.prepareStorage()
        #expect(try await store.read("catalogue") != nil)
        let reopened = SyncedBookRepository(bundled: MemoryBooks(values: []),
            transport: try TestCatalogueTransport([sample()]), cacheURL: directory.appending(path: "catalogue.json"), store: store)
        #expect(try await reopened.books() == [sample()])
    }

    @Test func lateBundledImportCannotOverwriteNewerDownloadedCatalogue() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let transport = try TestCatalogueTransport([sample(), sample("new")])
        let cache = directory.appending(path: "catalogue.json")
        let first = SyncedBookRepository(bundled: MemoryBooks(values: [sample()]), transport: transport, cacheURL: cache, store: store)
        let second = SyncedBookRepository(bundled: MemoryBooks(values: [sample()]), transport: transport, cacheURL: cache, store: store)
        _ = try await first.books()
        _ = try await second.sync()
        try await first.prepareStorage()
        let next = SyncedBookRepository(bundled: MemoryBooks(values: []), transport: transport, cacheURL: cache, store: store)
        #expect(try await next.books().map(\.id) == ["cafe", "new"])
    }
}

#if !canImport(CuentivaAppModel)
private final class BinaryLibraryFixtureBundle: NSObject {}
#endif
