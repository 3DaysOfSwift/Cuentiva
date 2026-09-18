import CryptoKit
import Foundation

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
    let endpoint: URL
    func fetch(pack: PackDescriptor?) async throws -> Data {
        guard endpoint.scheme == "https" else { throw AppFailure.invalidBook }
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
    private var currentBooks: [Book]?
    private var currentAuthors: [Author] = Author.demoProfiles
    private var syncing = false
    private var currentArrivals: [String: Date] = [:]
    private var preparedURL: URL { cacheURL.appendingPathExtension("prepared") }
    init(bundled: any BookRepository, transport: any CatalogueTransport, cacheURL: URL, store: SwiftDataStore? = nil) {
        self.store = store ?? SwiftDataStore(url: cacheURL.appendingPathExtension("store"))
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
                    && !book.sentences.isEmpty && book.fullText.count <= 1000
                    && Set(book.fullText.map(\.id)).count == book.fullText.count
                    && book.fullText.allSatisfy { !$0.id.isEmpty && !$0.spanish.isEmpty && !$0.english.isEmpty }
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
        if let data = try await store.value("packs", key: ref.id + "-" + ref.checksum),
            let pack = try? Self.decode(data, descriptor: ref)
        {
            return pack
        }
        // Existing file caches are read-only migration sources.

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
        guard let rows = try await store.read("catalogue") else { return nil }
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
    private func saveCatalogue(
        books: [Book], authors: [Author], arrivals: [String: Date], manifest: CatalogueManifest?,
        importing: Bool = false
    ) async throws {
        let header = CatalogueHeader(
            manifest: manifest, books: books.map(\.id), authors: authors.map(\.id), arrivals: arrivals)
        var rows = ["header": try RecordCoding.encode(header)]
        for book in books { rows["book/" + book.id] = try RecordCoding.encode(book) }
        for author in authors { rows["author/" + author.id] = try RecordCoding.encode(author) }
        try await store.replace("catalogue", values: rows, onlyIfAbsent: importing)
    }
    func books() async throws -> [Book] {
        if let currentBooks { return currentBooks }
        if let (header, books, authors) = try await readCatalogue() {
            currentBooks = books
            currentAuthors = authors
            currentArrivals = header.arrivals
            LegacyJSONCleanup.remove([cacheURL, preparedURL, directory])
            return books
        }
        // One-time import. Remove obsolete files only after the database is readable.
        if let prepared = readPreparedCatalogue() {
            try await saveCatalogue(
                books: prepared.books, authors: prepared.authors, arrivals: prepared.arrivals,
                manifest: prepared.manifest, importing: true)
        } else if let size = try? cacheURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 409_600,
            let data = try? Data(contentsOf: cacheURL),
            let manifest = try? JSONDecoder().decode(CatalogueManifest.self, from: data), manifest.valid
        {
            var packs: [LibraryPack] = []
            for ref in manifest.packs { if let pack = try await cachedPack(ref) { packs.append(pack) } }
            if packs.count == manifest.packs.count, let (books, authors) = try? assemble(packs) {
                try await saveCatalogue(
                    books: books, authors: authors, arrivals: [:], manifest: manifest, importing: true)
            }
        }
        if try await store.read("catalogue") == nil {
            let books = try await bundled.books()
            let authors = await bundled.authors()
            try await saveCatalogue(books: books, authors: authors, arrivals: [:], manifest: nil, importing: true)
        }
        guard let (header, books, authors) = try await readCatalogue() else { throw AppFailure.invalidBook }
        currentBooks = books
        currentAuthors = authors
        currentArrivals = header.arrivals
        LegacyJSONCleanup.remove([cacheURL, preparedURL, directory])
        return books
    }
    func sync() async throws -> [Book] {
        guard !syncing else { throw AppFailure.busy }
        syncing = true
        defer { syncing = false }
        _ = try await books()
        let data = try await transport.fetch(pack: nil)
        guard data.count <= 409_600 else { throw AppFailure.invalidBook }
        let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: data)
        guard manifest.valid else { throw AppFailure.invalidBook }
        let previous = try await readCatalogue()
        if let previous, previous.0.manifest == manifest { return previous.1 }
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
            try await store.put("packs", key: ref.id + "-" + ref.checksum, data: payload)
            packs.append(pack)
        }
        let (books, authors) = try assemble(packs)
        try Task.checkCancellation()
        // Book records and the catalogue index commit in one database transaction.
        // Failed preparation preserves the previous usable catalogue.
        let previousArrivals = previous?.0.arrivals ?? currentArrivals
        let existingIDs = Set((currentBooks ?? []).map(\.id))
        let downloadedAt = Date()
        let arrivals = Dictionary(
            uniqueKeysWithValues: books.map {
                ($0.id, previousArrivals[$0.id] ?? (existingIDs.contains($0.id) ? Date.distantPast : downloadedAt))
            })
        try await saveCatalogue(books: books, authors: authors, arrivals: arrivals, manifest: manifest)
        // Do not replace this session's catalogue. The next repository/launch
        // reads the new catalogue; personal books remain independent.
        return books
    }
}
