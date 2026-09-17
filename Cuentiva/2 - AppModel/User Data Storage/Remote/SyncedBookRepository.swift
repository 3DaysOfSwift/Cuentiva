import Foundation
import CryptoKit

struct CatalogueManifest: Codable, Equatable, Sendable {
    let schema: Int
    let version: String
    let bytes: Int
    let chunks: Int
    let books: Int
    var valid: Bool {
        schema == 1 && version.count == 64 && version.allSatisfy { "0123456789abcdef".contains($0) } &&
        bytes > 0 && bytes <= 1_048_576 && chunks > 0 && chunks <= 1100 && bytes <= chunks * 1024 && books > 0 && books <= 500
    }
}
protocol CatalogueTransport: Sendable { func fetch(version: String?, part: Int?) async throws -> Data }
struct WixCatalogueTransport: CatalogueTransport {
    let endpoint: URL
    func fetch(version: String?, part: Int?) async throws -> Data {
        guard endpoint.scheme == "https" else { throw AppFailure.unavailable("The library requires a secure connection.") }
        var url = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        if let version, let part { url.queryItems = [.init(name: "version", value: version), .init(name: "part", value: String(part))] }
        var request = URLRequest(url: url.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/json, text/plain", forHTTPHeaderField: "Accept")
        let (stream, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.url?.scheme == "https", response.expectedContentLength <= 1024 else {
            throw AppFailure.unavailable("The community library is temporarily unavailable. Your downloaded books are still here.")
        }
        var data = Data()
        for try await byte in stream {
            guard data.count < 1024 else { throw AppFailure.invalidBook }
            data.append(byte)
        }
        return data
    }
}
protocol SyncingBookRepository: BookRepository { func sync() async throws -> [Book] }
actor SyncedBookRepository: SyncingBookRepository {
    private struct Cache: Codable { let manifest: CatalogueManifest; let payload: Data }
    private let bundled: any BookRepository
    private let transport: any CatalogueTransport
    private let cacheURL: URL
    private var cached: Cache?
    private var loaded = false
    private var syncing = false
    init(bundled: any BookRepository, transport: any CatalogueTransport, cacheURL: URL) {
        self.bundled = bundled; self.transport = transport; self.cacheURL = cacheURL
    }
    static func decode(_ data: Data, manifest: CatalogueManifest) throws -> [Book] {
        guard manifest.valid, data.count == manifest.bytes,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == manifest.version else { throw AppFailure.invalidBook }
        let books = try JSONDecoder().decode([Book].self, from: data)
        guard books.count == manifest.books, Set(books.map(\.id)).count == books.count, books.contains(where: { $0.id == "cafe" }),
              books.allSatisfy({ book in
                  !book.id.isEmpty && !book.title.isEmpty && !book.englishTitle.isEmpty && !book.author.isEmpty &&
                  LearningLevel.allCases.contains(where: { $0.rawValue == book.level }) && book.palette >= 0 &&
                  !book.sentences.isEmpty && book.fullText.count <= 1000 && Set(book.fullText.map(\.id)).count == book.fullText.count &&
                  book.fullText.allSatisfy { !$0.id.isEmpty && !$0.spanish.isEmpty && !$0.english.isEmpty } &&
                  book.vocabulary.allSatisfy { !$0.word.isEmpty && !$0.lemma.isEmpty && $0.occurrences > 0 } &&
                  (book.submissionLocation == nil || (book.isDemoLocation == true && book.submissionLocation?.valid == true))
              }) else { throw AppFailure.invalidBook }
        return books
    }
    func books() async throws -> [Book] {
        if !loaded {
            loaded = true
            if let data = try? Data(contentsOf: cacheURL), data.count <= 1_500_000,
               let cache = try? JSONDecoder().decode(Cache.self, from: data),
               (try? Self.decode(cache.payload, manifest: cache.manifest)) != nil { cached = cache }
        }
        if let cached { return try Self.decode(cached.payload, manifest: cached.manifest) }
        return try await bundled.books()
    }
    func sync() async throws -> [Book] {
        guard !syncing else { throw AppFailure.busy }
        syncing = true; defer { syncing = false }
        _ = try await books()
        let manifestData = try await transport.fetch(version: nil, part: nil)
        guard manifestData.count <= 1024 else { throw AppFailure.invalidBook }
        let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: manifestData)
        guard manifest.valid else { throw AppFailure.invalidBook }
        if cached?.manifest == manifest { return try await books() }
        var payload = Data()
        // Sequential bounded batches avoid flooding Wix quotas; each result retains its index.
        for start in stride(from: 0, to: manifest.chunks, by: 4) {
            let pieces = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
                for part in start..<min(start + 4, manifest.chunks) {
                    group.addTask { [transport] in
                        let data = try await transport.fetch(version: manifest.version, part: part)
                        guard !data.isEmpty && data.count <= 1024 else { throw AppFailure.invalidBook }
                        return (part, data)
                    }
                }
                var results: [(Int, Data)] = []
                for try await result in group { results.append(result) }
                return results.sorted { $0.0 < $1.0 }
            }
            for (_, data) in pieces { payload.append(data) }
            guard payload.count <= manifest.bytes else { throw AppFailure.invalidBook }
        }
        let books = try Self.decode(payload, manifest: manifest)
        try Task.checkCancellation()
        // The only commit: no partial releases and no mutation of learner progress.
        let cache = Cache(manifest: manifest, payload: payload)
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(cache).write(to: cacheURL, options: .atomic)
        cached = cache
        return books
    }
}
