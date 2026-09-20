import Foundation

struct VerbTrainingState: Codable, Equatable, Sendable {
    var roundID = UUID()
    var phraseID: String?
    var position = 0
    var cloud: [String] = []
    var history: [String] = []
    var repetitions: [String: Int] = [:]
    // Optional fields let an interrupted pre-workout exercise migrate safely.
    var usedTiles: [Int]?
    var workoutStart: Int?
    var workoutDay: String?
    var completionReviewed: Bool?
    mutating func reviewCompletion(round: UUID) throws {
        guard round == roundID, setComplete else { throw AppFailure.incomplete }
        completionReviewed = true
    }
    mutating func refreshDay(_ day: String) {
        if let previous = workoutDay, previous != day {
            let completedSet = setComplete
            phraseID = nil; position = 0; cloud = []; usedTiles = []
            roundID = UUID()
            workoutStart = completedSet ? nil : total
        }
        // Preserve existing workouts when upgrading from versions without dates.
        workoutDay = day
    }
    var focusedSet: FocusedVerbSet?
    var isFocused: Bool { focusedSet != nil }
    var workoutTitle: String {
        focusedSet.map { "Practise \($0.verbID) · \($0.time.title)" } ?? "Your sentence workout"
    }
    var phrase: VerbPhrase? { phraseID.flatMap(VerbCatalogue.phrase) }
    var finished: Bool { phrase.map { position == $0.words.count } ?? false }
    var total: Int { repetitions.values.reduce(0, +) }
    var rep: Int { min(12, max(1, total - (workoutStart ?? total) + (finished ? 0 : 1))) }
    var setComplete: Bool { finished && total - (workoutStart ?? total) >= 12 }
    var built: String { phrase?.words.prefix(max(0, position)).joined(separator: " ") ?? "" }
    mutating func next(after round: UUID?) throws {
        guard round == (phraseID == nil ? nil : roundID), phraseID == nil || finished else {
            throw AppFailure.unavailable("Finish this rep before moving to the next one.")
        }
        if workoutStart == nil || setComplete {
            // Existing in-progress sets remain sentence sets; new learners begin focused.
            focusedSet = focusedSet == nil ? FocusedVerbSet.random() : nil
            workoutStart = total
        }
        let candidate = focusedSet.map { $0.phrase(rep: total - (workoutStart ?? total)) }
            ?? VerbCatalogue.randomPhrase(excluding: phraseID)
        guard let next = candidate else {
            throw AppFailure.unavailable("No practice sentences are available.")
        }
        try select(next.id)
    }
    mutating func prepare() throws {
        if phraseID == nil { try next(after: nil) }
        else if usedTiles == nil, let id = phraseID {
            // The old cloud revealed one word at a time. Rebuild only an unfinished
            // legacy rep; keep completed counts and the entire existing trail.
            if !finished { try select(id) }
            else { usedTiles = []; workoutStart = total - 1 }
        }
    }
    mutating func select(_ id: String) throws {
        guard let phrase = VerbCatalogue.phrase(id: id), !phrase.words.isEmpty else {
            throw AppFailure.unavailable("This practice sentence is unavailable.")
        }
        phraseID = id; position = 0; roundID = UUID(); usedTiles = []
        if workoutStart == nil { workoutStart = total }
        // Keep duplicate answer occurrences: e.g. two instances of “y” need two tiles.
        let words = phrase.words
        let answerSet = Set(words.map(WordComparison.normalized))
        let pool = Array(Set(VerbCatalogue.verbs.flatMap { verb in
            verb.forms.values.flatMap { $0 } + verb.tail.split(separator: " ").map(String.init)
        })).filter { !$0.isEmpty && !answerSet.contains(WordComparison.normalized($0)) }
        guard pool.count >= words.count else { throw AppFailure.unavailable("Not enough word tiles for this rep.") }
        cloud = (words + Array(pool.shuffled().prefix(isFocused ? min(2, words.count) : words.count))).shuffled()
    }
    mutating func choose(_ word: String, round: UUID, index: Int) throws -> Bool {
        guard round == roundID, index == position, let phrase, phrase.words.indices.contains(position),
              let usedTiles, let tile = cloud.indices.first(where: { cloud[$0] == word && !usedTiles.contains($0) }) else {
            throw AppFailure.unavailable("This sentence has changed. Use the current word tiles.")
        }
        guard word == phrase.words[position] else { return false }
        self.usedTiles?.append(tile)
        position += 1
        if finished {
            repetitions[phrase.id, default: 0] += 1
            history.append(phrase.id)
            if setComplete { completionReviewed = false }
        }
        return true
    }
}
enum VerbTrainingAction: Sendable {
    case claimGift
    case reviewCompletion(round: UUID)
    case refreshDay
    case prepare
    case next(after: UUID?)
    // Targeted selection remains an internal content/testing operation; the screen
    // exclusively asks the feature to choose the next random rep.
    case select(String)
    case choose(String, round: UUID, index: Int)
}
