import Foundation
import Testing
import CryptoKit
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct CatalogueSyncTests {
    @Test func importsLegacyPacksAndFailedReleaseKeepsDatabaseCatalogue() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appending(path: "catalogue.json")
        let packs = directory.appending(path: "packs-v2")
        try FileManager.default.createDirectory(at: packs, withIntermediateDirectories: true)
        let original = try TestCatalogueTransport([sample(), sample("legacy")])
        let manifestData = try await original.fetch(pack: nil)
        let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: manifestData)
        try manifestData.write(to: cache)
        for ref in manifest.packs {
            try await original.fetch(pack: ref).write(to: packs.appending(path: ref.id + "-" + ref.checksum + ".json"))
        }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let source = MemoryBooks(values: [sample()])
        let repository = SyncedBookRepository(bundled: source, transport: original, cacheURL: cache, store: store)
        #expect(try await repository.books().map(\.id) == ["cafe", "legacy"])
        #expect(!FileManager.default.fileExists(atPath: packs.path))
        #expect(!FileManager.default.fileExists(atPath: cache.path))
        #expect(try await SyncedBookRepository(bundled: source, transport: original, cacheURL: cache, store: store).books().count == 2)
        #if DEBUG
        // Same packs, changed manifest: failure occurs at catalogue commit rather than pack download.
        let revised = try TestCatalogueTransport([sample(), sample("legacy")])
        // Cache verified packs before injecting the failure.
        for ref in manifest.packs {
            try await store.put("packs", key: ref.id + "-" + ref.checksum, data: original.fetch(pack: ref))
        }
        await revised.changeVersion()
        let update = SyncedBookRepository(bundled: source, transport: revised, cacheURL: cache, store: store)
        let before = try await store.read("catalogue")
        try await store.failNextCommitForTesting()
        await #expect(throws: (any Error).self) { try await update.sync() }
        #expect(try await store.read("catalogue") == before)
        _ = try await update.sync()
        #expect(try await store.read("catalogue") != before)
        #endif
    }
    @Test func databaseLaunchDoesNotNeedLegacyJSONFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let cache = directory.appending(path: "catalogue.json")
        let source = MemoryBooks(values: [sample()])
        let transport = try TestCatalogueTransport([sample(), sample("downloaded")])
        let repository = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        _ = try await repository.sync()
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "packs-v2").path))
        let reloaded = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await reloaded.books().map(\.id) == ["cafe", "downloaded"])
        #expect(await reloaded.arrivals()["downloaded"] != nil)
        try Data("broken".utf8).write(to: cache.appendingPathExtension("prepared"))
        let fallback = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await fallback.books().map(\.id) == ["cafe", "downloaded"])
        // The database is authoritative; obsolete JSON cannot replace it.
        _ = try await fallback.sync()
        let repaired = SyncedBookRepository(bundled: source, transport: transport, cacheURL: cache, store: store)
        #expect(try await repaired.books().count == 2)
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
