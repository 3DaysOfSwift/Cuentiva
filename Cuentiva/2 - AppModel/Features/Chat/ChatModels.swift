import Foundation

enum ChatLimits {
    static let message = 500
    static let memory = 500
    static let recentExchanges = 2
    static let authorName = 30
    static let biography = 400
    static let replyText = 900
    static let correction = 500
    static let suggestion = 250
    // The model can return a longer summary, but only `memory` characters are retained.
    static let generatedMemory = 700

    static func normalizedMessage(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func acceptsMessage(_ value: String) -> Bool {
        let text = normalizedMessage(value)
        return !text.isEmpty && text.count <= message
    }
    static func acceptsReply(_ reply: ChatReply) -> Bool {
        !normalizedMessage(reply.spanish).isEmpty && !normalizedMessage(reply.english).isEmpty
            && reply.spanish.count <= replyText && reply.english.count <= replyText
            && reply.correction.count <= correction && reply.suggestion.count <= suggestion
            && reply.memory.count <= generatedMemory
    }

}

struct ChatTurn: Codable, Identifiable, Sendable {
    var id = UUID()
    var question: String
    var spanish: String
    var english: String
    var correction: String
    var suggestion: String
}
struct ChatConversation: Codable, Sendable {
    var turns: [ChatTurn] = []
    var memory = ""
}
struct ChatReply: Sendable {
    var spanish: String
    var english: String
    var correction: String
    var suggestion: String
    var memory: String
}
struct ChatRequest: Sendable {
    let name: String
    let biography: String
    let level: String
    let memory: String
    let recent: [ChatTurn]
    let message: String
}
protocol ChatGenerator: Sendable {
    func availabilityMessage() async -> String?
    func reply(to request: ChatRequest) async throws -> ChatReply
}
