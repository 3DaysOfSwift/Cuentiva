import Foundation

enum VocabularyState: String, Codable, CaseIterable, Sendable { case unknown, learning, known }
enum LearningLevel: String, Codable, CaseIterable, Sendable { case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1", c2 = "C2" }
struct LearnerProgress: Codable, Sendable {
    var schemaVersion = 1
    var selectedLearningLevel: LearningLevel? = nil
    var completed: Set<String> = []
    // Legacy storage key: records sentence encounters (reading or optional practice).
    var attempts: [String: Set<String>] = [:]
    var positions: [String: Int] = [:]
    var practiceDays: Set<String> = []
    var vocabulary: [String: VocabularyState] = [:]
    var seenWords: Set<String>? = nil
    var wordHistoryComplete: Bool? = nil
    var bookWordBaselines: [String: Set<String>]? = nil
    var celebratedCompletionDays: Set<String>? = nil
    var rewardedBooks: Set<String>? = nil
    var bestMatches: [String: Int]? = nil
    var doubloons: Int? = nil
    var evidence: [String: Int] = [:]
}
struct CompletionReceipt: Identifiable, Sendable {
    let id = UUID()
    let book: Book
    let isNew: Bool
    let total: Int
    var streakCelebration: Int? = nil
}
struct WeekDay: Identifiable { let id: String; let label: String; let practiced: Bool; let today: Bool }
