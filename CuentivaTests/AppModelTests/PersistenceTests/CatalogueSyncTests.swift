import Foundation
import Testing
import CryptoKit
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct CatalogueSyncTests {
    @Test func legacyPacksMigrateInBackgroundWithoutChangingCurrentSession() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appending(path: "catalogue.json")
        let packs = directory.appending(path: "packs-v2")
        try FileManager.default.createDirectory(at: packs, withIntermediateDirectories: true)
        let transport = try TestCatalogueTransport([sample(), sample("legacy")])
        let data = try await transport.fetch(pack: nil)
        let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: data)
        try data.write(to: cache)
        for ref in manifest.packs {
            try await transport.fetch(pack: ref).write(to: packs.appending(path: ref.id + "-" + ref.checksum + ".json"))
        }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let source = MemoryBooks(values: [sample()])
        let repository = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await repository.books() == [sample()])
        #expect(FileManager.default.fileExists(atPath: cache.path))
        _ = try await repository.sync()
        #expect(try await repository.books() == [sample()])
        #expect(!FileManager.default.fileExists(atPath: cache.path))
        let next = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await next.books().map(\.id) == ["cafe", "legacy"])
    }

    @Test func oldDatabaseCatalogueMigratesWithoutChangingReadingProgress() async throws {
        struct LegacyHeader: Codable {
            let manifest: CatalogueManifest?
            let books: [String]
            let authors: [String]
            let arrivals: [String: Date]
        }
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let source = MemoryBooks(values: [sample()])
        let books = [sample(), sample("legacy-db")]
        let author = Author.demoProfiles[0]
        let header = LegacyHeader(manifest: nil, books: books.map(\.id), authors: [author.id], arrivals: [:])
        var rows = ["header": try RecordCoding.encode(header), "author/" + author.id: try RecordCoding.encode(author)]
        for book in books { rows["book/" + book.id] = try RecordCoding.encode(book) }
        try await store.replace("catalogue", values: rows)
        let progressRepository = LocalProgressRepository(url: directory.appending(path: "progress.json"), store: store)
        var progress = try await progressRepository.load()
        progress.completed.insert("legacy-db")
        try await progressRepository.save(progress)
        let transport = try TestCatalogueTransport([sample()]); await transport.fail()
        let cache = directory.appending(path: "catalogue.json")
        let repository = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await repository.books() == [sample()])
        #expect(try await store.read("catalogue") != nil)
        // Migration commits locally even when the following network check fails.
        await #expect(throws: AppFailure.self) { try await repository.sync() }
        #expect(try await store.read("catalogue") == nil)
        #expect(try await progressRepository.load() == progress)
        let next = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await next.books() == books)
    }

    @Test func snapshotContainsEverythingNeededWithoutDatabaseOrPackFiles() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let cache = directory.appending(path: "catalogue.json")
        let transport = try TestCatalogueTransport([sample(), sample("downloaded")])
        let repository = SyncedBookRepository(bundled: MemoryBooks(values: [sample()]), transport: transport, cacheURL: cache, store: store)
        _ = try await repository.sync()
        try FileManager.default.removeItem(at: directory.appending(path: "packs-v2"))
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "app.store").path))
        let next = SyncedBookRepository(bundled: MemoryBooks(values: []), transport: transport, cacheURL: cache, store: store)
        #expect(try await next.books().map(\.id) == ["cafe", "downloaded"])
        #expect(await next.authors() == [Author.demoProfiles[0]])
        #expect(await next.arrivals()["downloaded"] != nil)
    }

    @Test func corruptSnapshotUsesBundleAndOnlySuccessfulUpdateRepairsIt() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let cache = directory.appending(path: "catalogue.json")
        let transport = try TestCatalogueTransport([sample()])
        let repository = SyncedBookRepository(bundled: MemoryBooks(values: [sample()]), transport: transport, cacheURL: cache, store: store)
        _ = try await repository.sync()
        let url = await repository.snapshotURL
        var data = try Data(contentsOf: url)
        data[data.count - 1] ^= 1
        try data.write(to: url)
        let next = SyncedBookRepository(bundled: MemoryBooks(values: [sample()]), transport: transport, cacheURL: cache, store: store)
        #expect(try await next.books() == [sample()])
        #expect(try Data(contentsOf: url) == data)
        _ = try await next.sync()
        #expect(try Data(contentsOf: url) != data)
        let repaired = SyncedBookRepository(bundled: MemoryBooks(values: []), transport: transport, cacheURL: cache, store: store)
        #expect(try await repaired.books().map(\.id) == ["cafe"])
    }
    @Test func replacesBundleWithoutDuplicatesAndCachesOffline() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let cache = directory.appending(path: "catalogue.json")
        let source = MemoryBooks(values: [sample(), sample("old")])
        let transport = try TestCatalogueTransport([sample(), sample("new")])
        let repository = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await repository.books().map(\.id) == ["cafe", "old"])
        #expect(try await repository.sync().map(\.id) == ["cafe", "new"])
        #expect(try await repository.books().map(\.id) == ["cafe", "old"])
        let reads = await transport.partReads
        _ = try await repository.sync()
        #expect(await transport.partReads == reads)
        let reloaded = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await reloaded.books().map(\.id) == ["cafe", "new"])
        #expect(await reloaded.authors() == [Author.demoProfiles[0]])
        let failing = try TestCatalogueTransport([sample(), sample("later")]); await failing.fail()
        let offline = SyncedBookRepository(bundled: source, transport: failing, cacheURL: cache, store: store)
        await #expect(throws: AppFailure.self) { try await offline.sync() }
        #expect(try await offline.books().map(\.id) == ["cafe", "new"])
    }
    @Test func failedAtomicWriteKeepsInstalledSnapshotAndCachedPacksCanRetry() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let cache = directory.appending(path: "catalogue.json"), source = MemoryBooks(values: [sample()])
        let original = SyncedBookRepository(bundled: source, transport: try TestCatalogueTransport([sample(), sample("old")]),
            cacheURL: cache, store: store)
        _ = try await original.sync()
        let url = await original.snapshotURL
        let before = try Data(contentsOf: url)
        let transport = try TestCatalogueTransport([sample(), sample("new")])
        let failing = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store,
            writeSnapshot: { _, _ in throw AppFailure.unavailable("Disk full") })
        await #expect(throws: AppFailure.self) { try await failing.sync() }
        #expect(try Data(contentsOf: url) == before)
        #expect(try await failing.books().map(\.id) == ["cafe", "old"])
        let reads = await transport.partReads
        let retry = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        _ = try await retry.sync()
        #expect(await transport.partReads == reads)
        let next = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await next.books().map(\.id) == ["cafe", "new"])
    }

    @Test func onlyChangedRevisionDownloadsAndInterruptedSyncResumes() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let cache = directory.appending(path: "catalogue.json"), source = MemoryBooks(values: [sample()])
        let a = try TestCatalogueTransport([sample(), sample("old")])
        _ = try await SyncedBookRepository(bundled: source, transport: a, cacheURL: cache, store: store).sync()
        let b = try TestCatalogueTransport([sample(), sample("new"), sample("third")])
        await b.failOnly("pack-2")
        let repo = SyncedBookRepository(bundled: source, transport: b, cacheURL: cache, store: store)
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
            let scenario = directory.appending(path: UUID().uuidString)
            let store = SwiftDataStore(url: scenario.appending(path: "app.store"))
            let transport = try TestCatalogueTransport(books)
            let repository = SyncedBookRepository(bundled: source, transport: transport, cacheURL: scenario.appending(path: "catalogue.json"), store: store)
            await #expect(throws: AppFailure.self) { try await repository.sync() }
            #expect(try await repository.books().count == 1)
        }
        let transport = try TestCatalogueTransport([sample()]); await transport.corrupt("pack-0")
        let store = SwiftDataStore(url: directory.appending(path: "bad/app.store"))
        let repo = SyncedBookRepository(bundled: source, transport: transport, cacheURL: directory.appending(path: "bad/catalogue.json"), store: store)
        await #expect(throws: AppFailure.self) { try await repo.sync() }
    }
    @Test func authorOnlyRevisionUpdatesAlongsideBooks() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let cache = directory.appending(path: "catalogue.json"), source = MemoryBooks(values: [sample()])
        let a = try TestCatalogueTransport([sample()])
        _ = try await SyncedBookRepository(bundled: source, transport: a, cacheURL: cache, store: store).sync()
        let author = Author(id: "ana", name: "Ana", portrait: "", introduction: "New introduction", note: "New note")
        let b = try TestCatalogueTransport([sample()], author: author)
        let repo = SyncedBookRepository(bundled: source, transport: b, cacheURL: cache, store: store)
        _ = try await repo.sync()
        #expect(await b.partReads == 1)
        #expect(await repo.authors() == [Author.demoProfiles[0]])
        let nextLaunch = SyncedBookRepository(bundled: source, transport: b, cacheURL: cache, store: store)
        _ = try await nextLaunch.books()
        #expect(await nextLaunch.authors() == [author])
    }
}
