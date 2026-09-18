import Foundation

struct FantasyArchive: Codable, Sendable {
    var introductionSeen: Bool? = nil
    var profile: FantasyProfile?
    var stories: [FantasyStory] = []
    var publications: [FantasyPublication]? = nil
}

protocol FantasyRepository: Sendable {
    func load() async throws -> FantasyArchive
    func save(_ archive: FantasyArchive) async throws
}

actor LocalFantasyRepository: FantasyRepository {
    private let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> FantasyArchive {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        return try JSONDecoder().decode(FantasyArchive.self, from: Data(contentsOf: url))
    }
    func save(_ archive: FantasyArchive) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(archive).write(to: url, options: .atomic)
    }
}
