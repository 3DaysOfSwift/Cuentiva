import Foundation
import CryptoKit

struct PackDescriptor: Codable, Equatable, Sendable {
    let id: String
    let checksum: String
    let bytes: Int
    let books: Int
    var release: String? = nil
    var valid: Bool {
        !id.isEmpty && id.count <= 100 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") } &&
        checksum.count == 64 && checksum.allSatisfy { "0123456789abcdef".contains($0) } && bytes > 0 && bytes <= 409_600 && books > 0 && books <= 13
    }
}
struct CatalogueManifest: Codable, Equatable, Sendable {
    let schema: Int
    let version: String
    let packs: [PackDescriptor]
    var valid: Bool {
        schema == 2 && version.count == 64 && version.allSatisfy { "0123456789abcdef".contains($0) } &&
        !packs.isEmpty && packs.count <= 2000 && packs.allSatisfy(\.valid) && Set(packs.map(\.id)).count == packs.count &&
        packs.reduce(0, { $0 + $1.books }) <= 20_000 && packs.reduce(0, { $0 + $1.bytes }) <= 268_435_456
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
                  release.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { throw AppFailure.invalidBook }
            url = endpoint.appending(path: "releases/download/" + release + "/" + pack.id + "-" + pack.checksum + ".json")
        } else {
            url = endpoint.appending(path: "releases/latest/download/catalogue.json")
        }
        // Immutable revisions can be cached by URL; refresh the small index each sync.
        var request = URLRequest(url: url, cachePolicy: pack == nil ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (stream, response) = try await URLSession.shared.bytes(for: request)
        let limit = pack?.bytes ?? 409_600
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.url?.scheme == "https", response.expectedContentLength <= limit else { throw AppFailure.unavailable("The library is temporarily unavailable.") }
        var data = Data()
        for try await byte in stream {
            guard data.count < limit else { throw AppFailure.invalidBook }; data.append(byte)
        }
        return data
    }
}
protocol SyncingBookRepository: BookRepository { func sync() async throws -> [Book] }
actor SyncedBookRepository: SyncingBookRepository {
    private let bundled: any BookRepository
    private let transport: any CatalogueTransport
    private let cacheURL: URL
    private var currentBooks: [Book]?
    private var currentAuthors: [Author] = Author.demoProfiles
    private var syncing = false
    init(bundled: any BookRepository, transport: any CatalogueTransport, cacheURL: URL) {
        self.bundled = bundled; self.transport = transport; self.cacheURL = cacheURL
    }
    private var directory: URL { cacheURL.deletingLastPathComponent().appending(path: "packs-v2") }
    private func file(_ ref: PackDescriptor) -> URL { directory.appending(path: ref.id + "-" + ref.checksum + ".json") }
    static func decode(_ data: Data, descriptor: PackDescriptor) throws -> LibraryPack {
        guard descriptor.valid, data.count == descriptor.bytes,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == descriptor.checksum else { throw AppFailure.invalidBook }
        let pack = try JSONDecoder().decode(LibraryPack.self, from: data)
        guard pack.schema == 2, pack.id == descriptor.id, pack.books.count == descriptor.books else { throw AppFailure.invalidBook }
        let books = pack.books
        guard Set(books.map(\.id)).count == books.count,
              books.allSatisfy({ book in
                  !book.id.isEmpty && !book.title.isEmpty && !book.englishTitle.isEmpty && !book.author.isEmpty &&
                  LearningLevel.allCases.contains(where: { $0.rawValue == book.level }) && book.palette >= 0 &&
                  !book.sentences.isEmpty && book.fullText.count <= 1000 && Set(book.fullText.map(\.id)).count == book.fullText.count &&
                  book.fullText.allSatisfy { !$0.id.isEmpty && !$0.spanish.isEmpty && !$0.english.isEmpty } &&
                  book.vocabulary.allSatisfy { !$0.word.isEmpty && !$0.lemma.isEmpty && $0.occurrences > 0 } &&
                  (book.submissionLocation == nil || (book.isDemoLocation == true && book.submissionLocation?.valid == true))
              }) else { throw AppFailure.invalidBook }
        let ids = Set(pack.authors.map(\.id))
        guard !ids.isEmpty, ids.count == pack.authors.count, pack.authors.count <= 13,
              books.allSatisfy({ $0.authorID.map(ids.contains) == true }),
              pack.authors.allSatisfy({ author in
                  !author.id.isEmpty && !author.name.isEmpty && !author.introduction.isEmpty && !author.note.isEmpty &&
                  Author.supportedPortraits.contains(author.portrait) && books.contains { $0.authorID == author.id }
              }) else { throw AppFailure.invalidBook }
        return pack
    }
    private func cachedPack(_ ref: PackDescriptor) -> LibraryPack? {
        let url = file(ref)
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size == ref.bytes,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decode(data, descriptor: ref)
    }
    private func assemble(_ packs: [LibraryPack]) throws -> ([Book], [Author]) {
        let books = packs.flatMap(\.books)
        guard Set(books.map(\.id)).count == books.count, books.contains(where: { $0.id == "cafe" }) else { throw AppFailure.invalidBook }
        var authors: [Author] = [], byID: [String: Author] = [:]
        for author in packs.flatMap(\.authors) {
            if let old = byID[author.id] { guard old == author else { throw AppFailure.invalidBook } }
            else { byID[author.id] = author; authors.append(author) }
        }
        return (books, authors)
    }
    func authors() async -> [Author] { currentAuthors }
    func books() async throws -> [Book] {
        if let currentBooks { return currentBooks }
        if let size = try? cacheURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 409_600,
           let data = try? Data(contentsOf: cacheURL), let m = try? JSONDecoder().decode(CatalogueManifest.self, from: data), m.valid {
            let packs = m.packs.compactMap { cachedPack($0) }
            if packs.count == m.packs.count, let (books, authors) = try? assemble(packs) {
                currentBooks = books; currentAuthors = authors; return books
            }
        }
        // Includes migration from the previous whole-catalogue cache. Never discard progress.
        let books = try await bundled.books(); currentBooks = books; currentAuthors = await bundled.authors(); return books
    }
    func sync() async throws -> [Book] {
        guard !syncing else { throw AppFailure.busy }
        syncing = true; defer { syncing = false }
        _ = try await books()
        let data = try await transport.fetch(pack: nil)
        guard data.count <= 409_600 else { throw AppFailure.invalidBook }
        let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: data)
        guard manifest.valid else { throw AppFailure.invalidBook }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var packs: [LibraryPack] = []
        for ref in manifest.packs {
            try Task.checkCancellation()
            if let pack = cachedPack(ref) { packs.append(pack); continue }
            let payload = try await transport.fetch(pack: ref)
            let pack = try Self.decode(payload, descriptor: ref)
            // Verified individual downloads survive an interrupted sync and are reused on retry.
            try payload.write(to: file(ref), options: .atomic)
            packs.append(pack)
        }
        let (books, authors) = try assemble(packs)
        try Task.checkCancellation()
        // One commit point for the library. Failed releases preserve its previous index.
        try JSONEncoder().encode(manifest).write(to: cacheURL, options: .atomic)
        currentBooks = books; currentAuthors = authors
        return books
    }
}
