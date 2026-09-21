//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import CryptoKit
import Foundation
import OSLog

struct PackDescriptor: Codable, Equatable, Sendable {
    let id: String
    let checksum: String
    let bytes: Int
    let books: Int
    var release: String? = nil
    var valid: Bool {
        !id.isEmpty && id.count <= 100
            && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
            && checksum.count == 64 && checksum.allSatisfy { "0123456789abcdef".contains($0) } && bytes > 0
            && bytes <= 409_600 && books > 0 && books <= 13
    }
}
struct CatalogueManifest: Codable, Equatable, Sendable {
    let schema: Int
    let version: String
    let packs: [PackDescriptor]
    var valid: Bool {
        schema == 2 && version.count == 64 && version.allSatisfy { "0123456789abcdef".contains($0) } && !packs.isEmpty
            && packs.count <= 2000 && packs.allSatisfy(\.valid) && Set(packs.map(\.id)).count == packs.count
            && packs.reduce(0, { $0 + $1.books }) <= 20_000 && packs.reduce(0, { $0 + $1.bytes }) <= 268_435_456
    }
}
struct LibraryPack: Codable, Sendable {
    let schema: Int
    let id: String
    let authors: [Author]
    let books: [Book]
}
protocol CatalogueTransport: Sendable { func fetch(pack: PackDescriptor?) async throws -> Data }
struct GitHubCatalogueTransport: CatalogueTransport {
    let endpoint: URL?
    func fetch(pack: PackDescriptor?) async throws -> Data {
        guard let endpoint, endpoint.scheme == "https" else {
            throw AppFailure.unavailable("The library download address is invalid.")
        }
        let url: URL
        if let pack {
            guard pack.valid, let release = pack.release, !release.isEmpty, release.count <= 100,
                release.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
            else { throw AppFailure.invalidBook }
            url = endpoint.appending(
                path: "releases/download/" + release + "/" + pack.id + "-" + pack.checksum + ".json")
        } else {
            url = endpoint.appending(path: "releases/latest/download/catalogue.json")
        }
        // Immutable revisions can be cached by URL; refresh the small index each sync.
        var request = URLRequest(
            url: url, cachePolicy: pack == nil ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy,
            timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (stream, response) = try await URLSession.shared.bytes(for: request)
        let limit = pack?.bytes ?? 409_600
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
            response.url?.scheme == "https", response.expectedContentLength <= limit
        else { throw AppFailure.unavailable("The library is temporarily unavailable.") }
        var data = Data()
        for try await byte in stream {
            guard data.count < limit else { throw AppFailure.invalidBook }
            data.append(byte)
        }
        return data
    }
}
protocol SyncingBookRepository: BookRepository { func sync() async throws -> [Book] }
private struct PreparedCatalogue: Codable {
    let schema: Int
    let manifest: CatalogueManifest
    let books: [Book]
    let authors: [Author]
    let arrivals: [String: Date]
    var valid: Bool {
        schema == 1 && manifest.valid && !books.isEmpty && books.count <= 20_000
            && Set(books.map(\.id)).count == books.count && books.contains { $0.id == "cafe" }
    }
}
actor SyncedBookRepository: SyncingBookRepository {
    private let bundled: any BookRepository
    private let transport: any CatalogueTransport
    private let cacheURL: URL
    private let store: SwiftDataStore
    private let writeSnapshot: @Sendable (Data, URL) throws -> Void
    private var currentBooks: [Book]?
    private var currentAuthors: [Author] = Author.demoProfiles
    private var syncing = false
    private var currentArrivals: [String: Date] = [:]
    private var preparedURL: URL { cacheURL.appendingPathExtension("prepared") }
    var snapshotURL: URL { cacheURL.deletingLastPathComponent().appending(path: "core-library.dat") }
    private var migratedStorage = false
    init(bundled: any BookRepository, transport: any CatalogueTransport, cacheURL: URL, store: SwiftDataStore,
         writeSnapshot: @escaping @Sendable (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) {
        self.writeSnapshot = writeSnapshot
        self.store = store
        self.bundled = bundled
        self.transport = transport
        self.cacheURL = cacheURL
    }
    private var directory: URL { cacheURL.deletingLastPathComponent().appending(path: "packs-v2") }
    private func file(_ ref: PackDescriptor) -> URL { directory.appending(path: ref.id + "-" + ref.checksum + ".json") }
    static func decode(_ data: Data, descriptor: PackDescriptor) throws -> LibraryPack {
        guard descriptor.valid, data.count == descriptor.bytes,
            SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == descriptor.checksum
        else { throw AppFailure.invalidBook }
        let pack = try JSONDecoder().decode(LibraryPack.self, from: data)
        guard pack.schema == 2, pack.id == descriptor.id, pack.books.count == descriptor.books else {
            throw AppFailure.invalidBook
        }
        let books = pack.books
        guard Set(books.map(\.id)).count == books.count,
            books.allSatisfy({ book in
                !book.id.isEmpty && !book.title.isEmpty && !book.englishTitle.isEmpty && !book.author.isEmpty
                    && LearningLevel.allCases.contains(where: { $0.rawValue == book.level }) && book.palette >= 0
                    && (book.editorialRevision == nil || (book.editorialRevision ?? 0) > 0)
                    && !book.sentences.isEmpty && book.completeText.count <= 1000
                    && Set(book.completeText.map(\.id)).count == book.completeText.count
                    && book.completeText.allSatisfy { !$0.id.isEmpty && !$0.spanish.isEmpty && !$0.english.isEmpty }
                    && book.vocabulary.allSatisfy { !$0.word.isEmpty && !$0.lemma.isEmpty && $0.occurrences > 0 }
                    && (book.submissionLocation == nil
                        || (book.isDemoLocation == true && book.submissionLocation?.valid == true))
            })
        else { throw AppFailure.invalidBook }
        let ids = Set(pack.authors.map(\.id))
        guard !ids.isEmpty, ids.count == pack.authors.count, pack.authors.count <= 13,
            books.allSatisfy({ $0.authorID.map(ids.contains) == true }),
            pack.authors.allSatisfy({ author in
                !author.id.isEmpty && !author.name.isEmpty && !author.introduction.isEmpty && !author.note.isEmpty
                    && Author.supportedPortraits.contains(author.portrait)
                    && books.contains { $0.authorID == author.id }
            })
        else { throw AppFailure.invalidBook }
        return pack
    }
    private func cachedPack(_ ref: PackDescriptor) async throws -> LibraryPack? {
        let url = file(ref)
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size == ref.bytes,
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? Self.decode(data, descriptor: ref)
    }
    private func assemble(_ packs: [LibraryPack]) throws -> ([Book], [Author]) {
        let books = packs.flatMap(\.books)
        guard Set(books.map(\.id)).count == books.count, books.contains(where: { $0.id == "cafe" }) else {
            throw AppFailure.invalidBook
        }
        var authors: [Author] = []
        var byID: [String: Author] = [:]
        for author in packs.flatMap(\.authors) {
            if let old = byID[author.id] {
                guard old == author else { throw AppFailure.invalidBook }
            } else {
                byID[author.id] = author
                authors.append(author)
            }
        }
        return (books, authors)
    }
    private func readPreparedCatalogue() -> PreparedCatalogue? {
        guard let size = try? preparedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            size <= 300_000_000, let data = try? Data(contentsOf: preparedURL),
            let prepared = try? JSONDecoder().decode(PreparedCatalogue.self, from: data),
            prepared.valid
        else { return nil }
        return prepared
    }
    func authors() async -> [Author] { currentAuthors }
    func arrivals() async -> [String: Date] { currentArrivals }
    private struct CatalogueHeader: Codable {
        let manifest: CatalogueManifest?
        let books: [String]
        let authors: [String]
        let arrivals: [String: Date]
    }
    private func readCatalogue() async throws -> (CatalogueHeader, [Book], [Author])? {
        guard let rows = try await store.readIfPresent("catalogue") else { return nil }
        guard let data = rows["header"] else { throw AppFailure.invalidBook }
        let header = try RecordCoding.decode(CatalogueHeader.self, data)
        func read<T: Codable>(_ type: T.Type, key: String) throws -> T {
            guard let data = rows[key] else { throw AppFailure.invalidBook }
            return try RecordCoding.decode(type, data)
        }
        let books = try header.books.map { try read(Book.self, key: "book/" + $0) }
        let authors = try header.authors.map { try read(Author.self, key: "author/" + $0) }
        guard Set(header.books).count == books.count, !books.isEmpty else { throw AppFailure.invalidBook }
        return (header, books, authors)
    }
    /// A launch only reads a prepared file or the bundled library. No database,
    /// migration, download or write participates in this path.
    func books() async throws -> [Book] {
        if let currentBooks { return currentBooks }
        if let prepared = readSnapshot() {
            // An installed pack must not roll a newer bundled editorial edition
            // back to the old text. Keep remote-only books and newer revisions.
            var books = prepared.books
            var authors = prepared.authors
            do {
                let bundledBooks = try await bundled.books()
                let bundledAuthors = await bundled.authors()
                for replacement in bundledBooks where (replacement.editorialRevision ?? 0) > 0 {
                    if let index = books.firstIndex(where: { $0.id == replacement.id }) {
                        guard (replacement.editorialRevision ?? 0) > (books[index].editorialRevision ?? 0) else { continue }
                        books[index] = replacement
                    } else {
                        books.append(replacement)
                    }
                    if let author = bundledAuthors.first(where: { $0.id == replacement.authorID }) {
                        authors.removeAll { $0.id == author.id }
                        authors.append(author)
                    }
                }
            } catch {
                // The verified snapshot is still useful if the bundle is unavailable.
                Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "Library")
                    .error("Bundled editorial update could not be read; using the installed snapshot.")
            }
            if let currentBooks { return currentBooks }
            currentBooks = books
            currentAuthors = authors
            currentArrivals = prepared.arrivals
            return books
        }
        let books = try await bundled.books()
        let authors = await bundled.authors()
        // Publish both together after the final suspension point.
        if let currentBooks { return currentBooks }
        currentAuthors = authors
        currentBooks = books
        return books
    }
    func introduction() async throws -> Book { try await bundled.introduction() }

    private func readSnapshot() -> CoreLibrarySnapshot? {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return nil }
        do { return try CoreLibrarySnapshot(url: snapshotURL) }
        catch {
            // Downloaded content is replaceable. Keep the damaged file until a
            // complete update succeeds; use the bundled core in the meantime.
            Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "LibraryLoading")
                .error("Installed core snapshot could not be read. Using bundled content until an update repairs it.")
            return nil
        }
    }

    private func saveSnapshot(_ snapshot: CoreLibrarySnapshot) throws {
        let data = try snapshot.encoded()
        // Validate the exact bytes before atomic replacement. Interruption or
        // failed validation leaves the previous version available.
        let decoded = try CoreLibrarySnapshot(data: data)
        guard decoded.books == snapshot.books, decoded.authors == snapshot.authors,
              decoded.arrivals == snapshot.arrivals, decoded.manifest == snapshot.manifest else {
            throw AppFailure.invalidBook
        }
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeSnapshot(data, snapshotURL)
    }

    /// Only the background update workflow calls this compatibility bridge.
    /// Existing progress remains in the same store and is never removed.
    private func migrateLegacyCatalogue() async throws {
        guard !migratedStorage else { return }
        if !FileManager.default.fileExists(atPath: snapshotURL.path) {
            if let (header, books, authors) = try await readCatalogue() {
                try saveSnapshot(.init(manifest: header.manifest, books: books, authors: authors, arrivals: header.arrivals))
            } else if let prepared = readPreparedCatalogue() {
                try saveSnapshot(.init(manifest: prepared.manifest, books: prepared.books,
                                       authors: prepared.authors, arrivals: prepared.arrivals))
            } else if FileManager.default.fileExists(atPath: cacheURL.path) {
                let data = try Data(contentsOf: cacheURL)
                guard data.count <= 409_600 else { throw AppFailure.invalidBook }
                let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: data)
                guard manifest.valid else { throw AppFailure.invalidBook }
                var packs: [LibraryPack] = []
                for ref in manifest.packs {
                    if let pack = try await cachedPack(ref) { packs.append(pack) }
                }
                if packs.count == manifest.packs.count {
                    let (books, authors) = try assemble(packs)
                    try saveSnapshot(.init(manifest: manifest, books: books, authors: authors, arrivals: [:]))
                }
            }
        }
        if readSnapshot() != nil {
            try await store.removeCollection("catalogue")
            try await store.removeCollection("packs")
            LegacyJSONCleanup.remove([cacheURL, preparedURL])
        }
        migratedStorage = true
    }

    func sync() async throws -> [Book] {
        guard !syncing else { throw AppFailure.busy }
        syncing = true
        defer { syncing = false }
        _ = try await books()
        try await migrateLegacyCatalogue()
        let data = try await transport.fetch(pack: nil)
        guard data.count <= 409_600 else { throw AppFailure.invalidBook }
        let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: data)
        guard manifest.valid else { throw AppFailure.invalidBook }
        let previous = readSnapshot()
        if let previous, previous.manifest == manifest { return previous.books }
        var packs: [LibraryPack] = []
        for ref in manifest.packs {
            try Task.checkCancellation()
            if let pack = try await cachedPack(ref) {
                packs.append(pack)
                continue
            }
            let payload = try await transport.fetch(pack: ref)
            let pack = try Self.decode(payload, descriptor: ref)
            // Verified individual downloads survive an interrupted sync and are reused on retry.
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try payload.write(to: file(ref), options: .atomic)
            packs.append(pack)
        }
        let (books, authors) = try assemble(packs)
        try Task.checkCancellation()
        // All core content and metadata activate together on the next launch.
        let previousArrivals = previous?.arrivals ?? currentArrivals
        let existingIDs = Set((currentBooks ?? []).map(\.id))
        let downloadedAt = Date()
        let arrivals = Dictionary(
            uniqueKeysWithValues: books.map {
                ($0.id, previousArrivals[$0.id] ?? (existingIDs.contains($0.id) ? Date.distantPast : downloadedAt))
            })
        try saveSnapshot(.init(manifest: manifest, books: books, authors: authors, arrivals: arrivals))
        // Do not replace this session's catalogue. The next repository/launch
        // reads the new catalogue; personal books remain independent.
        return books
    }
}

/// One atomic snapshot: small binary-plist metadata, offset-table book bytes,
/// and a SHA-256 integrity checksum. JSON is only the publishing transport.
private struct CoreLibrarySnapshot {
    let manifest: CatalogueManifest?
    let books: [Book]
    let authors: [Author]
    let arrivals: [String: Date]
    private struct Header: Codable {
        let manifest: CatalogueManifest?
        let authors: [Author]
        let arrivals: [String: Date]
    }
    init(manifest: CatalogueManifest?, books: [Book], authors: [Author], arrivals: [String: Date]) {
        self.manifest = manifest; self.books = books; self.authors = authors; self.arrivals = arrivals
    }
    init(url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= 300_000_000 else { throw AppFailure.invalidBook }
        try self.init(data: Data(contentsOf: url))
    }
    init(data: Data) throws {
        guard data.count >= 64, data.count <= 300_000_000,
              data.prefix(8) == Data("CUENCORE".utf8) else { throw AppFailure.invalidBook }
        let version = data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 8, as: UInt32.self)) }
        let length = data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 12, as: UInt32.self)) }
        guard version == 1, length <= 10_000_000, Int(length) <= data.count - 48,
              Data(SHA256.hash(data: data.dropLast(32))) == data.suffix(32) else { throw AppFailure.invalidBook }
        let boundary = 16 + Int(length)
        let header = try PropertyListDecoder().decode(Header.self, from: data.subdata(in: 16..<boundary))
        let books = try BinaryLibrary(data: data.subdata(in: boundary..<(data.count - 32))).books()
        guard header.manifest?.valid != false,
              Set(books.map(\.id)).count == books.count, books.contains(where: { $0.id == "cafe" }),
              Set(header.authors.map(\.id)).count == header.authors.count else { throw AppFailure.invalidBook }
        self.init(manifest: header.manifest, books: books, authors: header.authors, arrivals: header.arrivals)
    }
    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let header = try encoder.encode(Header(manifest: manifest, authors: authors, arrivals: arrivals))
        guard header.count <= 10_000_000, let length = UInt32(exactly: header.count) else { throw AppFailure.invalidBook }
        var data = Data("CUENCORE".utf8)
        for value in [UInt32(1), length] {
            var little = value.littleEndian
            data.append(withUnsafeBytes(of: &little) { Data($0) })
        }
        data.append(header)
        data.append(try BinaryLibrary.encode(books))
        data.append(Data(SHA256.hash(data: data)))
        return data
    }
}
