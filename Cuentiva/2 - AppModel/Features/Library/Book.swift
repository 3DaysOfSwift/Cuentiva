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
    var wordCount: Int { sentences.reduce(0) { $0 + WordComparison.words($1.spanish).count } }
}
struct Sentence: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let spanish: String
    let english: String
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
