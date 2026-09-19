import Foundation

protocol ChatRepository: Sendable {
    func load() async throws -> [String: ChatConversation]
    func save(_ conversations: [String: ChatConversation]) async throws
}
actor LocalChatRepository: ChatRepository {
    private let url: URL
    private let store: SwiftDataStore
    init(url: URL, store: SwiftDataStore) {
        self.url = url
        self.store = store
    }
    private struct Header: Codable {
        let author: String
        let memory: String
        let turns: [UUID]
    }
    private func prefix(_ author: String) -> String { Data(author.utf8).base64EncodedString() }
    func load() async throws -> [String: ChatConversation] {
        if let rows = try await store.read("chat") {
            let value = try decode(rows)
            LegacyJSONCleanup.remove([url])
            return value
        }
        let legacy =
            FileManager.default.fileExists(atPath: url.path)
            ? try JSONDecoder().decode([String: ChatConversation].self, from: Data(contentsOf: url)) : [:]
        let rows = try await store.replace("chat", values: encode(legacy), onlyIfAbsent: true)
        let value = try decode(rows)
        LegacyJSONCleanup.remove([url])
        return value
    }
    func save(_ conversations: [String: ChatConversation]) async throws {
        try await store.replace("chat", values: encode(conversations))
    }
    private func encode(_ conversations: [String: ChatConversation]) throws -> [String: Data] {
        var rows: [String: Data] = [:]
        for (author, conversation) in conversations {
            guard Set(conversation.turns.map(\.id)).count == conversation.turns.count else {
                throw AppFailure.unavailable("Duplicate chat turn identifiers.")
            }
            rows["header/" + prefix(author)] = try RecordCoding.encode(
                Header(author: author, memory: conversation.memory, turns: conversation.turns.map(\.id)))
            for turn in conversation.turns {
                rows["turn/" + prefix(author) + "/" + turn.id.uuidString] = try RecordCoding.encode(turn)
            }
        }
        return rows
    }
    private func decode(_ rows: [String: Data]) throws -> [String: ChatConversation] {
        var values: [String: ChatConversation] = [:]
        for (key, data) in rows where key.hasPrefix("header/") {
            let header = try RecordCoding.decode(Header.self, data)
            let turns = try header.turns.map { id in
                guard let data = rows["turn/" + prefix(header.author) + "/" + id.uuidString] else {
                    throw AppFailure.unavailable("A saved conversation is incomplete.")
                }
                return try RecordCoding.decode(ChatTurn.self, data)
            }
            values[header.author] = ChatConversation(turns: turns, memory: header.memory)
        }
        return values
    }
}
