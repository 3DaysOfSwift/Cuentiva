import Foundation

struct Book: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let englishTitle: String
    let author: String
    let level: String
    let symbol: String
    let palette: Int
    let summary: String
    let sentences: [Sentence]
    let vocabulary: [VocabularyEntry]
    let license: String
    var isDemoLocation: Bool? = nil
    var submissionLocation: StoryLocation? = nil
    var format: BookFormat? = nil
    var scene: String? = nil
    var continuation: [Sentence]? = nil
    var verbFocus: VerbFocus? = nil
    var fullText: [Sentence] { sentences + (continuation ?? []) }
    var kind: BookFormat { format ?? .story }
    var unitName: String { kind == .movieScript ? "lines" : "sentences" }
    var cast: [String] { fullText.compactMap(\.speaker).reduce(into: []) { if !$0.contains($1) { $0.append($1) } } }
    var wordCount: Int { fullText.reduce(0) { $0 + WordComparison.words($1.spanish).count } }
}
struct Sentence: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let spanish: String
    let english: String
    var speaker: String? = nil
}
struct VocabularyEntry: Codable, Hashable, Sendable {
    let word: String
    let lemma: String
    let occurrences: Int
}
enum AppFailure: LocalizedError {
    case locked, incomplete, emptyAnswer, unavailable(String), invalidBook, busy
    var errorDescription: String? {
        switch self {
        case .locked: "Unlock Cuentiva with a one-time purchase or restore your purchase to continue."
        case .incomplete: "Read every sentence before completing this book."
        case .emptyAnswer: "Write or say a few words before checking your answer."
        case .unavailable(let message): message
        case .invalidBook: "This book could not be loaded. Please try again."
        case .busy: "A save is already in progress. Please try again."
        }
    }
}

enum BookFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case story, movieScript, verbs
    var id: Self { self }
    var title: String { switch self { case .story: "Stories"; case .movieScript: "Movie Scripts"; case .verbs: "Verbs" } }
    var singular: String { switch self { case .story: "Story"; case .movieScript: "Movie Script"; case .verbs: "Verb Story" } }
}
enum BookSort: String, CaseIterable, Identifiable, Sendable {
    case library, title, difficulty, type
    var id: Self { self }
    var title: String {
        switch self { case .library: "Library order"; case .title: "Title A–Z"; case .difficulty: "Difficulty"; case .type: "Book type" }
    }
}

struct VerbFocus: Codable, Hashable, Sendable {
    let infinitive: String
    let tense: String
    let forms: [String]
    let scope: String
}
