import Foundation

/// The draw identifies a bundled creature, independently of AI availability.
enum FantasyCreature: Int, Codable, CaseIterable, Sendable, Identifiable {
    case turtle = 1, unicorn, fox
    static func weightedDraw(ticket: Int) -> FantasyCreature {
        precondition((1...10).contains(ticket))
        return switch ticket { case 1...8: .fox; case 9: .turtle; default: .unicorn }
    }
    var id: Int { rawValue }
    var title: String {
        switch self { case .turtle: "Turtle"; case .unicorn: "Winged unicorn"; case .fox: "Fox" }
    }
    var portrait: String {
        switch self { case .turtle: "SpiritTurtle"; case .unicorn: "SpiritUnicorn"; case .fox: "SpiritFox" }
    }
}

struct FantasyIdentity: Codable, Equatable, Sendable {
    let name: String
    let biography: String
}

struct StorytellerDetails: Codable, Equatable, Sendable {
    let name: String
    let biography: String
}

struct FantasyProfile: Codable, Equatable, Sendable {
    let creature: FantasyCreature
    var revealNumber: Int? = nil
    var details: StorytellerDetails? = nil
    var identity: FantasyIdentity?
}

struct FantasySentence: Codable, Equatable, Sendable {
    let spanish: String
    let english: String
}

struct FantasyStory: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    let title: String
    let englishTitle: String
    let sentences: [FantasySentence]
}

protocol FantasyGenerator: Sendable {
    func availabilityMessage() async -> String?
    func identity(name: String, biography: String, creature: FantasyCreature) async throws -> FantasyIdentity
    func story(memory: String, profile: FantasyProfile) async throws -> FantasyStory
}

/// Validation applies to every provider before generated content can be saved.
enum FantasyValidation {
    static func identity(_ value: FantasyIdentity) throws {
        let name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 24, name.allSatisfy({ $0.isLetter }),
              !value.biography.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.biography.count <= 1200 else {
            throw AppFailure.unavailable("The storyteller needs one short name and a brief biography. Please try again.")
        }
    }
    static func story(_ value: FantasyStory) throws {
        guard !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !value.englishTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.sentences.count == 16,
              value.sentences.allSatisfy({ !$0.spanish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.spanish.count <= 500 && $0.english.count <= 500 }) else {
            throw AppFailure.unavailable("This tale needs sixteen complete Spanish–English sentence pairs. Please try again.")
        }
    }
}

extension FantasyGenerator {
    func availabilityMessage() async -> String? { nil }
}

/// Personal publications never pass through the shared catalogue transport.
struct FantasyPublication: Codable, Sendable {
    let storyID: UUID
    let publishedAt: Date
    let book: Book
}

@MainActor protocol PersonalLibraryFeature: AnyObject, Sendable {
    var publishedBooks: [Book] { get }
}

extension FantasyStory {
    func personalBook(author: Author) -> Book {
        let bookID = "personal-\(id.uuidString.lowercased())"
        let words = sentences.flatMap { WordComparison.words($0.spanish) }.map(WordComparison.normalized)
        let counts = Dictionary(grouping: words, by: { $0 })
        let vocabulary = counts.sorted { $0.key < $1.key }.map { word, occurrences in
            VocabularyEntry(word: word, lemma: word, occurrences: occurrences.count)
        }
        return Book(id: bookID, title: title, englishTitle: englishTitle, author: author.name,
                    level: "A2", symbol: "sparkles", palette: 0,
                    summary: "A personal tale from your own storyteller.",
                    sentences: sentences.enumerated().map {
                        Sentence(id: "\(bookID)-\($0.offset)", spanish: $0.element.spanish, english: $0.element.english)
                    }, vocabulary: vocabulary, license: "Private personal story",
                    authorID: author.id, personalAuthor: author)
    }
}
