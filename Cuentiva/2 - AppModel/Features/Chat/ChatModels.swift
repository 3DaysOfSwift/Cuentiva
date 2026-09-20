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
            && (reply.suggestionEnglish.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= suggestion } ?? true)
            && (reply.learnerEnglish.map { !normalizedMessage($0).isEmpty && $0.count <= replyText } ?? true)
            && reply.memory.count <= generatedMemory
            && reply.additionalMessages.count <= 2
            && reply.additionalMessages.allSatisfy {
                !normalizedMessage($0.spanish).isEmpty && !normalizedMessage($0.english).isEmpty
                    && $0.spanish.count <= replyText && $0.english.count <= replyText
            }
    }

}

struct ChatTurn: Codable, Identifiable, Sendable {
    var id = UUID()
    var question: String
    var questionEnglish: String? = nil
    var spanish: String
    var english: String
    var correction: String
    var suggestion: String
    var suggestionEnglish: String? = nil
}
enum ChatRole: String, Codable, Sendable { case learner, storyteller }
enum ChatDelivery: String, Codable, Sendable { case pending, delivered, failed }
struct ChatMessage: Codable, Identifiable, Sendable {
    var id = UUID()
    let role: ChatRole
    let text: String
    var delivery: ChatDelivery = .delivered
    var inReplyTo: UUID? = nil
    var english = ""
    var correction = ""
    var suggestion = ""
    var suggestionEnglish: String? = nil
}
struct ChatConversation: Codable, Sendable {
    var messages: [ChatMessage] = []
    var memory = ""

    // Older archives and the bounded generation context use exchanges. The
    // visible transcript is an ordered message array, with no alternating-role rule.
    var turns: [ChatTurn] {
        messages.compactMap { message in
            guard message.role == .storyteller, let replyID = message.inReplyTo,
                  let question = messages.first(where: { $0.id == replyID }) else { return nil }
            return ChatTurn(id: message.id, question: question.text, questionEnglish: question.english.isEmpty ? nil : question.english, spanish: message.text,
                english: message.english, correction: message.correction, suggestion: message.suggestion, suggestionEnglish: message.suggestionEnglish)
        }
    }
    init(turns: [ChatTurn] = [], memory: String = "") {
        self.memory = memory
        for turn in turns {
            let question = ChatMessage(role: .learner, text: turn.question, english: turn.questionEnglish ?? "")
            messages.append(question)
            messages.append(ChatMessage(id: turn.id, role: .storyteller, text: turn.spanish,
                inReplyTo: question.id, english: turn.english, correction: turn.correction, suggestion: turn.suggestion, suggestionEnglish: turn.suggestionEnglish))
        }
    }
    private enum CodingKeys: String, CodingKey { case messages, turns, memory }
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let memory = try values.decode(String.self, forKey: .memory)
        if let messages = try values.decodeIfPresent([ChatMessage].self, forKey: .messages) {
            self.init(memory: memory)
            self.messages = messages
        } else {
            self.init(turns: try values.decode([ChatTurn].self, forKey: .turns), memory: memory)
        }
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(messages, forKey: .messages)
        try values.encode(memory, forKey: .memory)
    }
}
struct ChatReplyMessage: Sendable {
    var spanish: String
    var english: String
}
struct ChatReply: Sendable {
    var spanish: String
    var english: String
    var correction: String
    var suggestion: String
    var memory: String
    var additionalMessages: [ChatReplyMessage] = []
    var suggestionEnglish: String? = nil
    var learnerEnglish: String? = nil
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
