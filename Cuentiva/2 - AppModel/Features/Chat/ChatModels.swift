//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

enum RolePlayDifficulty: String, Codable, CaseIterable, Sendable {
    case easy = "Easy"
    case natural = "Natural"
    case realMexico = "Real Mexico"
}

struct ScenarioVocabulary: Codable, Hashable, Sendable {
    let spanish: String
    let english: String
}

struct ConversationScenario: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let context: String
    let learnerRole: String
    let aiRole: String
    let level: LearningLevel
    let objective: String
    let instructions: String
    let usefulVocabulary: [ScenarioVocabulary]
    let requiredObjectives: [String]
    let optionalComplications: [String]

    static let catalogue: [ConversationScenario] = [
        .init(id: "order-coffee-mexico", title: "Order a Coffee", symbol: "cup.and.saucer.fill", context: "Café · Mexico", learnerRole: "Customer", aiRole: "Barista", level: .a1, objective: "Order a drink and respond to the questions a real barista might ask.", instructions: "Ask one thing at a time. Establish the drink, size, hot or cold, milk, for here or takeaway, anything else, and payment.", usefulVocabulary: [.init(spanish: "Quisiera…", english: "I would like…"), .init(spanish: "para llevar", english: "to take away"), .init(spanish: "¿Cuánto cuesta?", english: "How much does it cost?")], requiredObjectives: ["drink", "size", "temperature", "location", "payment"], optionalComplications: ["The requested milk is unavailable.", "The requested size is unavailable."]),
        .init(id: "order-tacos", title: "Order Tacos", symbol: "takeoutbag.and.cup.and.straw.fill", context: "Taquería · Mexico", learnerRole: "Customer", aiRole: "Server", level: .a1, objective: "Order food, choose fillings and answer practical questions.", instructions: "Help the learner order tacos naturally. Ask about filling, quantity, salsa, eating here or takeaway, and payment.", usefulVocabulary: [.init(spanish: "Quiero tres tacos", english: "I want three tacos"), .init(spanish: "sin cebolla", english: "without onion")], requiredObjectives: ["food", "quantity", "preferences", "payment"], optionalComplications: ["One filling has sold out.", "Only a spicy salsa remains."]),
        .init(id: "order-at-a-bar", title: "Order at a Bar", symbol: "wineglass.fill", context: "Bar · Mexico", learnerRole: "Customer", aiRole: "Bartender", level: .a2, objective: "Order a drink and handle the questions that follow.", instructions: "Ask what they want, clarify size or brand where natural, offer a snack, and arrange payment.", usefulVocabulary: [.init(spanish: "Una cerveza, por favor", english: "A beer, please"), .init(spanish: "La cuenta, por favor", english: "The bill, please")], requiredObjectives: ["drink", "clarification", "payment"], optionalComplications: ["The requested drink is unavailable.", "The bar accepts card only."]),
        .init(id: "taxi-ride", title: "Talk to a Taxi Driver", symbol: "car.fill", context: "Taxi or rideshare · Mexico", learnerRole: "Passenger", aiRole: "Driver", level: .a2, objective: "Confirm the destination and manage a realistic journey.", instructions: "Confirm the learner's name and destination, ask about the preferred route or drop-off, and discuss payment naturally.", usefulVocabulary: [.init(spanish: "Voy a…", english: "I am going to…"), .init(spanish: "Aquí está bien", english: "Here is fine")], requiredObjectives: ["destination", "route", "drop-off", "payment"], optionalComplications: ["Traffic requires another route.", "The exact entrance is closed."]),
        .init(id: "visit-pharmacy", title: "Visit a Pharmacy", symbol: "cross.case.fill", context: "Pharmacy · Mexico", learnerRole: "Customer", aiRole: "Pharmacist", level: .a2, objective: "Explain a simple need and understand ordinary pharmacy questions.", instructions: "Ask about the learner's basic non-emergency symptom, duration, allergies and preferred form. Do not diagnose or replace professional medical care.", usefulVocabulary: [.init(spanish: "Me duele…", english: "My … hurts"), .init(spanish: "Desde ayer", english: "Since yesterday")], requiredObjectives: ["need", "duration", "allergies", "product"], optionalComplications: ["The preferred format is unavailable.", "The pharmacist recommends speaking to a doctor."]),
        .init(id: "get-haircut", title: "Get a Haircut", symbol: "scissors", context: "Hair salon · Mexico", learnerRole: "Client", aiRole: "Stylist", level: .a2, objective: "Describe the haircut you want and answer follow-up questions.", instructions: "Ask about length, style, sides, washing and finishing. Confirm before making an important choice.", usefulVocabulary: [.init(spanish: "Solo un poco", english: "Only a little"), .init(spanish: "Más corto a los lados", english: "Shorter on the sides")], requiredObjectives: ["length", "style", "confirmation"], optionalComplications: ["The requested stylist is unavailable.", "A reference is ambiguous."]),
        .init(id: "buy-in-shop", title: "Buy Something", symbol: "cart.fill", context: "Shop · Mexico", learnerRole: "Customer", aiRole: "Shop assistant", level: .a1, objective: "Find an item, ask about it and complete the purchase.", instructions: "Ask what the learner needs, clarify colour or size where relevant, state a price and arrange payment.", usefulVocabulary: [.init(spanish: "¿Tiene…?", english: "Do you have…?"), .init(spanish: "¿Puedo pagar con tarjeta?", english: "Can I pay by card?")], requiredObjectives: ["item", "preference", "price", "payment"], optionalComplications: ["The preferred size is unavailable.", "There is a similar alternative."]),
        .init(id: "receive-delivery", title: "Receive a Delivery", symbol: "shippingbox.fill", context: "At home · Mexico", learnerRole: "Recipient", aiRole: "Delivery courier", level: .a2, objective: "Help a courier find you and receive a parcel.", instructions: "Confirm the recipient, building or entrance, delivery location and any required confirmation.", usefulVocabulary: [.init(spanish: "Ya bajo", english: "I am coming down now"), .init(spanish: "Déjelo en recepción", english: "Leave it at reception")], requiredObjectives: ["identity", "location", "handover"], optionalComplications: ["The courier is at the wrong entrance.", "A signature is required."]),
        .init(id: "talk-landlord", title: "Talk to a Landlord", symbol: "house.fill", context: "Home · Mexico", learnerRole: "Tenant", aiRole: "Landlord", level: .b1, objective: "Explain a household problem and agree what happens next.", instructions: "Ask for a clear description, when it began, access arrangements and a practical next step.", usefulVocabulary: [.init(spanish: "Hay un problema con…", english: "There is a problem with…"), .init(spanish: "¿Cuándo puede venir?", english: "When can you come?")], requiredObjectives: ["problem", "timing", "access", "resolution"], optionalComplications: ["A repair person cannot come today.", "More information is needed."]),
        .init(id: "meet-neighbour", title: "Meet a Neighbour", symbol: "hand.wave.fill", context: "Neighbourhood · Mexico", learnerRole: "New neighbour", aiRole: "Neighbour", level: .a1, objective: "Introduce yourself and begin a friendly neighbourly conversation.", instructions: "Exchange names, ask where the learner lives or comes from, share one local detail and close naturally.", usefulVocabulary: [.init(spanish: "Mucho gusto", english: "Nice to meet you"), .init(spanish: "Acabo de mudarme", english: "I just moved here")], requiredObjectives: ["introduction", "home", "local-detail"], optionalComplications: ["Invite the learner to a local event.", "Mention a neighbourhood custom."]),
        .init(id: "restaurant", title: "Eat at a Restaurant", symbol: "fork.knife", context: "Restaurant · Mexico", learnerRole: "Diner", aiRole: "Server", level: .a2, objective: "Navigate a meal from arrival to paying the bill.", instructions: "Ask about the table, drinks, food, preferences, anything else and payment. Keep the exchange natural and paced.", usefulVocabulary: [.init(spanish: "Una mesa para dos", english: "A table for two"), .init(spanish: "¿Qué recomienda?", english: "What do you recommend?")], requiredObjectives: ["table", "drink", "meal", "preferences", "bill"], optionalComplications: ["A dish is unavailable.", "Ask whether they want to add a tip."]),
        .init(id: "ask-directions", title: "Ask for Directions", symbol: "map.fill", context: "Street · Mexico", learnerRole: "Visitor", aiRole: "Local resident", level: .a2, objective: "Ask for a place and understand practical directions.", instructions: "Clarify the destination, give short step-by-step directions, mention one landmark and check understanding.", usefulVocabulary: [.init(spanish: "¿Cómo llego a…?", english: "How do I get to…?"), .init(spanish: "¿Está lejos?", english: "Is it far?")], requiredObjectives: ["destination", "directions", "landmark", "confirmation"], optionalComplications: ["The usual route is closed.", "There are two places with similar names."])
    ]
}

struct ConversationContext: Hashable, Sendable {
    let author: Author
    let scenario: ConversationScenario?
    let difficulty: RolePlayDifficulty

    init(author: Author, scenario: ConversationScenario? = nil, difficulty: RolePlayDifficulty = .easy) {
        self.author = author.storyteller
        self.scenario = scenario
        self.difficulty = difficulty
    }
    var storageKey: String { scenario.map { "role-play:\($0.id)" } ?? author.id }
    var title: String { scenario?.title ?? author.name }
    var subtitle: String { scenario.map { "\($0.aiRole) · \($0.context)" } ?? "AI storyteller" }
    var isRolePlay: Bool { scenario != nil }
}

enum ChatLimits {
    static let messagesPerCoin = 100
    static let returnWindow: TimeInterval = 10 * 60
    static let savedMessages = 400
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
struct ChatMessage: Codable, Identifiable, Sendable, Equatable {
    var id = UUID()
    let role: ChatRole
    let text: String
    var delivery: ChatDelivery = .delivered
    var inReplyTo: UUID? = nil
    var english = ""
    var correction = ""
    var suggestion = ""
    var suggestionEnglish: String? = nil
    var metObjectives: [String]? = nil
    var scenarioComplete: Bool? = nil
}
struct ChatConversation: Codable, Sendable, Equatable {
    var messages: [ChatMessage] = []
    var memory = ""
    var metObjectives: Set<String> { Set(messages.flatMap { $0.metObjectives ?? [] }) }
    var scenarioComplete: Bool { messages.contains { $0.scenarioComplete == true } }

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
    var metObjectives: [String] = []
    var scenarioComplete = false
}
struct ChatRequest: Sendable {
    let name: String
    let biography: String
    let level: String
    let memory: String
    let recent: [ChatTurn]
    let message: String
    let scenario: ConversationScenario?
    let difficulty: RolePlayDifficulty
    init(name: String, biography: String, level: String, memory: String, recent: [ChatTurn], message: String,
         scenario: ConversationScenario? = nil, difficulty: RolePlayDifficulty = .easy) {
        self.name = name; self.biography = biography; self.level = level; self.memory = memory
        self.recent = recent; self.message = message; self.scenario = scenario; self.difficulty = difficulty
    }
}
protocol ChatGenerator: Sendable {
    func availabilityMessage() async -> String?
    func reply(to request: ChatRequest) async throws -> ChatReply
}

/// Saved with the wallet debit and transcript in one progress transaction.
struct PaidChatSession: Codable, Sendable, Equatable {
    var receiptID: UUID
    var conversation: ChatConversation
    var sentMessages: Int
    var lastActivity: Date
    var resumeUntil: Date
    func canResume(at date: Date) -> Bool {
        sentMessages > 0 && sentMessages < ChatLimits.messagesPerCoin
            && date >= lastActivity && date < resumeUntil
            && resumeUntil.timeIntervalSince(lastActivity) <= ChatLimits.returnWindow
    }
}
