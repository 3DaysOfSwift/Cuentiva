//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import CryptoKit
import Testing
import StoreKit
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

actor MemoryProgress: ProgressRepository {
    var value = LearnerProgress()
    var fail = false
    var saveAttempts = 0
    func load() -> LearnerProgress { value }
    func save(_ value: LearnerProgress) throws {
        saveAttempts += 1
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
    var offers: [Product] { [] }
    var message: String?
    var refreshCalls = 0
    func refresh() async { refreshCalls += 1 }
    func purchase(plan: InAppPurchases) async throws { hasAccess = true }
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
    func changeVersion() { manifest = CatalogueManifest(schema: manifest.schema, version: String(repeating: "b", count: 64), packs: manifest.packs) }
    func fail() { broken = true }
    func failOnly(_ id: String?) { failID = id }
    func corrupt(_ id: String) { payloads[id] = Data("broken".utf8) }
    func fetch(pack: PackDescriptor?) throws -> Data {
        guard let pack else { return try JSONEncoder().encode(manifest) }
        partReads += 1
        if broken || failID == pack.id { throw AppFailure.unavailable("Offline") }
        return try #require(payloads[pack.id])
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

struct UnavailableFantasyGenerator: FantasyGenerator {
    func availabilityMessage() async -> String? { "Apple Intelligence is unavailable." }
    func identity(name: String, biography: String, creature: FantasyCreature) async throws -> FantasyIdentity { throw AppFailure.unavailable("No AI available") }
    func story(memory: String, profile: FantasyProfile) async throws -> FantasyStory { throw AppFailure.unavailable("No AI available") }
}

actor PersonalLibraryCatalogue: SyncingBookRepository {
    func books() -> [Book] { [sample("original")] }
    func sync() -> [Book] { [sample("replacement")] }
}
