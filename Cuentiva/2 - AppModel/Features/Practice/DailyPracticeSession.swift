import Foundation

enum DailyPracticeGame: String, Codable, CaseIterable, Identifiable, Sendable {
    case missingWord, sentenceBuilder, sentenceTrail
    var id: String { rawValue }
    var title: String {
        switch self {
        case .missingWord: "Missing Word"
        case .sentenceBuilder: "Build the Sentence"
        case .sentenceTrail: "Sentence Trail"
        }
    }
    var symbol: String {
        switch self {
        case .missingWord: "puzzlepiece.extension"
        case .sentenceBuilder: "text.word.spacing"
        case .sentenceTrail: "arrow.right.circle"
        }
    }
}
enum PracticeScenario: String, Codable, CaseIterable, Identifiable, Sendable {
    case books, coffee, bus
    var id: String { rawValue }
    var title: String {
        switch self { case .books: "Today’s books"; case .coffee: "Café: coconut milk"; case .bus: "Oaxaca → Puerto Escondido" }
    }
    var phrases: [PracticePhrase] {
        switch self {
        case .books: []
        case .coffee: [
            .init(spanish: "Quisiera un café con leche de coco, por favor.", english: "I would like a coffee with coconut milk, please.", source: title),
            .init(spanish: "¿Cuánto cuesta?", english: "How much does it cost?", source: title),
            .init(spanish: "Me lo llevo, gracias.", english: "I’ll take it to go, thank you.", source: title)]
        case .bus: [
            .init(spanish: "Quisiera un billete de autobús a Puerto Escondido, por favor.", english: "I would like a bus ticket to Puerto Escondido, please.", source: title),
            .init(spanish: "Salgo del centro de Oaxaca.", english: "I’m leaving from the centre of Oaxaca.", source: title),
            .init(spanish: "¿A qué hora sale el próximo autobús?", english: "What time does the next bus leave?", source: title)]
        }
    }
}
struct PracticePhrase: Codable, Equatable, Sendable {
    let spanish: String
    let english: String
    let source: String
    var words: [String] { spanish.split(whereSeparator: \.isWhitespace).map(String.init) }
}
struct DailyPracticeSession: Codable, Equatable, Sendable {
    let day: String
    let bookIDs: [String]
    let phrases: [PracticePhrase]
    let pool: [String]
    var completed: Set<DailyPracticeGame> = []
    var missingIndex = 0
    var builderIndex = 0
    var builderTokens: [Int] = []
    var scenario: PracticeScenario = .books
    var trailCloud: [String] = []
    var trailPhrase = 0
    var trailWord = 0
    var trailScore = 0
    var trailBroken = false
    var rewarded = false
    var rounds: Int { min(5, phrases.count) }
    var missingPhrase: PracticePhrase { phrases[min(missingIndex, phrases.count - 1)] }
    var builderPhrase: PracticePhrase { phrases[min(builderIndex + rounds, phrases.count - 1)] }
    var trailPhrases: [PracticePhrase] { scenario == .books ? phrases : scenario.phrases }
    var currentTrail: PracticePhrase { trailPhrases[trailPhrase % trailPhrases.count] }
    var valid: Bool {
        phrases.count >= 6 && phrases.allSatisfy { (3...22).contains($0.words.count) }
            && (0...rounds).contains(missingIndex) && (0...rounds).contains(builderIndex)
            && builderTokens.count < builderPhrase.words.count
            && Set(builderTokens).count == builderTokens.count
            && builderTokens.allSatisfy { builderPhrase.words.indices.contains($0) }
            && trailPhrase >= 0 && trailScore >= 0 && currentTrail.words.indices.contains(trailWord)
    }
    var missingPosition: Int { missingIndex % missingPhrase.words.count }
    var missingAnswer: String { missingPhrase.words[missingPosition] }
    var missingOptions: [String] { choices(correct: missingAnswer, seed: missingIndex) }
    var trailOptions: [String] { trailCloud.isEmpty ? choices(correct: currentTrail.words[trailWord], seed: trailScore) : trailCloud }
    mutating func selectScenario(_ value: PracticeScenario) throws {
        guard trailScore == 0, !completed.contains(.sentenceTrail) else { throw AppFailure.incomplete }
        scenario = value; trailPhrase = 0; trailWord = 0; trailCloud = []
    }
    var builderOrder: [Int] {
        // Stable across relaunches; duplicate words retain distinct tile IDs.
        builderPhrase.words.indices.sorted { rank("\(builderIndex)-\($0)") < rank("\(builderIndex)-\($1)") }
    }
    private func rank(_ text: String) -> UInt64 {
        (day + text).utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }
    private func choices(correct: String, seed: Int) -> [String] {
        let alternatives = pool.filter { $0 != correct }.sorted { rank("\(seed)-\($0)") < rank("\(seed)-\($1)") }
        return (Array(alternatives.prefix(7)) + [correct]).sorted { rank("tile-\(seed)-\($0)") < rank("tile-\(seed)-\($1)") }
    }
    static func make(day: String, books: [Book]) throws -> Self {
        guard books.count == 3, Set(books.map(\.id)).count == 3 else { throw AppFailure.incomplete }
        // Interleave all three books so each contributes to the short games.
        let lines = books.map { book in
            book.fullText.compactMap { sentence -> PracticePhrase? in
                let words = sentence.spanish.split(whereSeparator: \.isWhitespace)
                guard (3...22).contains(words.count), !sentence.english.isEmpty else { return nil }
                return .init(spanish: sentence.spanish, english: sentence.english, source: book.englishTitle)
            }
        }
        guard lines.allSatisfy({ !$0.isEmpty }) else { throw AppFailure.unavailable("These books need more practice sentences.") }
        var phrases: [PracticePhrase] = []
        for index in 0..<(lines.map(\.count).max() ?? 0) {
            for book in lines where book.indices.contains(index) { phrases.append(book[index]) }
        }
        guard phrases.count >= 6 else { throw AppFailure.incomplete }
        let pool = Array(Set(phrases.flatMap(\.words))).sorted()
        return .init(day: day, bookIDs: books.map(\.id), phrases: phrases, pool: pool)
    }
    /// A wrong choice in the first two games is feedback, not a new play-through.
    mutating func choose(_ choice: String, game: DailyPracticeGame) throws -> Bool {
        guard !completed.contains(game), !phrases.isEmpty else { throw AppFailure.incomplete }
        switch game {
        case .missingWord:
            guard missingOptions.contains(choice) else { throw AppFailure.incomplete }
            guard choice == missingAnswer else { return false }
            missingIndex += 1
            if missingIndex == rounds { completed.insert(game) }
        case .sentenceBuilder:
            guard let index = Int(choice), builderPhrase.words.indices.contains(index), !builderTokens.contains(index) else { throw AppFailure.incomplete }
            // Alternate occurrences of an identical word are interchangeable.
            guard builderPhrase.words[index] == builderPhrase.words[builderTokens.count] else { return false }
            builderTokens.append(index)
            if builderTokens.count == builderPhrase.words.count {
                builderTokens = []; builderIndex += 1
                if builderIndex == rounds { completed.insert(game) }
            }
        case .sentenceTrail:
            guard trailOptions.contains(choice) else { throw AppFailure.incomplete }
            guard choice == currentTrail.words[trailWord] else {
                trailBroken = true; completed.insert(game); return false
            }
            var cloud = trailOptions
            let usedIndex = cloud.firstIndex(of: choice) ?? 0
            trailScore += 1; trailWord += 1
            if trailWord == currentTrail.words.count { trailPhrase += 1; trailWord = 0 }
            let nextWord = currentTrail.words[trailWord]
            let replacement = cloud.contains(nextWord) && nextWord != choice
                ? pool.first(where: { !cloud.contains($0) }) ?? choice : nextWord
            cloud[usedIndex] = replacement
            trailCloud = cloud
        }
        return true
    }
}
