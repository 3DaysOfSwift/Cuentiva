import Foundation

protocol ChatRepository: Sendable {
    func load() async throws -> [String: ChatConversation]
    func save(_ conversations: [String: ChatConversation]) async throws
}
actor LocalChatRepository: ChatRepository {
    let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> [String: ChatConversation] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode([String: ChatConversation].self, from: Data(contentsOf: url))
    }
    func save(_ conversations: [String: ChatConversation]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(conversations).write(to: url, options: .atomic)
    }
}
