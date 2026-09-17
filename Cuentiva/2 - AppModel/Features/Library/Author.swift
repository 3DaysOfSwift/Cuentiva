import Foundation

/// Fictional editorial profiles for the bundled demo; not verified contributors.
struct Author: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let portrait: String
    let introduction: String
    let note: String
    static let demoProfiles: [Author] = [
        .init(id: "ana", name: "Ana", portrait: "AuthorAna", introduction: "Small cafés. Familiar faces. The everyday moments that make a neighbourhood feel like home.", note: "A familiar café can be the beginning of a friendship. That is the feeling behind my little story."),
        .init(id: "luis", name: "Luis", portrait: "AuthorLuis", introduction: "Gardens, family and the things we learn when we slow down long enough to notice.", note: "In this story, a garden becomes a way to remember a father—and the care he passed on."),
        .init(id: "marta", name: "Marta", portrait: "AuthorMarta", introduction: "Journeys, reunions and the quiet excitement of finding our way back to the people we love.", note: "Sometimes a train ticket means more than a journey. It means someone is waiting for you.")
    ]
}
