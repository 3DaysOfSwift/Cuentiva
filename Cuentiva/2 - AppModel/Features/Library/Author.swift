import Foundation
import CryptoKit

/// Fictional editorial profiles for the bundled demo; not verified contributors.
struct Author: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let portrait: String
    let introduction: String
    let note: String
    /// Stable within a Monday–Sunday UTC week, with a different lead credit each week.
    /// Rotate a deterministic shuffled baseline so smaller collections cannot repeat by chance.
    static func weeklyOrder(_ authors: [Author], on date: Date) -> [Author] {
        guard authors.count > 1 else { return authors }
        let ordered = authors.sorted {
            let lhs = SHA256.hash(data: Data($0.id.utf8)).map { String(format: "%02x", $0) }.joined()
            let rhs = SHA256.hash(data: Data($1.id.utf8)).map { String(format: "%02x", $0) }.joined()
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
        let week = Int(floor((date.timeIntervalSince1970 - 345_600) / 604_800))
        let offset = ((week % ordered.count) + ordered.count) % ordered.count
        return Array(ordered[offset...] + ordered[..<offset])
    }
    /// Preserve legacy pack IDs while presenting the app's permanent storyteller cast.
    var storyteller: Author {
        if let character = Self.demoProfiles.first(where: { $0.id == id }) { return character }
        return Author(id: id, name: name.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? name,
                      portrait: portrait, introduction: introduction, note: note)
    }
    static let supportedPortraits: Set<String> = Set(["", "AuthorAna", "AuthorLuis", "AuthorMarta"])
        .union(demoProfiles.map(\.portrait))
    static let pipa: Author = .init(id: "marta", name: "Pipa", portrait: "StorytellerPipa", introduction: "A curious lizard with a travel notebook and a talent for finding new paths.", note: "Every journey begins with a question. Mine is usually: what is around that corner?")
    static let demoProfiles: [Author] = [
        .init(id: "ana", name: "Brasa", portrait: "StorytellerBrasa", introduction: "A little dragon with a generous heart and a weakness for café stories.", note: "I collect small acts of kindness. There is usually a cup of coffee nearby."),
        .init(id: "luis", name: "Musgo", portrait: "StorytellerMusgo", introduction: "A woodland wizard who finds magic in gardens, family and everyday care.", note: "Slow down with me. The smallest things often have the biggest stories."),
        pipa,
        .init(id: "credit-fade9533cfe2", name: "Zumi", portrait: "StorytellerZumi", introduction: "A tiny fly with enormous curiosity about work, ideas and how things happen.", note: "I ask questions, make mistakes and try again. Come and see what we discover."),
        .init(id: "credit-53e13e40b11a", name: "Luma", portrait: "StorytellerLuma", introduction: "A gentle moth who follows the light of a good idea.", note: "An ordinary day can hold a surprising possibility. Let us look for one together."),
        .init(id: "credit-5b644d127a59", name: "Nube", portrait: "StorytellerNube", introduction: "A wandering cloud creature with a pocket full of stories and a playful imagination.", note: "I bring tales about being human: the funny moments, the difficult choices and the joy of starting again."),
        .init(id: "credit-4ffea73372fb", name: "Tilo", portrait: "StorytellerTilo", introduction: "A patient tortoise who loves listening to people and bringing their conversations to life.", note: "Take a part, say a line and join the conversation. There is a place for your voice here."),
        .init(id: "credit-0047224f3651", name: "Mora", portrait: "StorytellerMora", introduction: "A mischievous mushroom sprite who makes words spring into action.", note: "Words change when our stories change. Let us discover what they can do."),
        .init(id: "credit-5f7d24711b1b", name: "Faro", portrait: "StorytellerFaro", introduction: "A curious owl with a map, a satchel and a love of faraway places.", note: "Follow me into a new neighbourhood. There is always another story waiting around the corner."),
    ]
}
