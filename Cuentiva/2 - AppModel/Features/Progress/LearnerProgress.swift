import Foundation

enum VocabularyState: String, Codable, CaseIterable, Sendable { case unknown, learning, known }
struct LearnerProgress: Codable, Sendable {
    var schemaVersion = 1
    var completed: Set<String> = []
    // Legacy storage key: records sentence encounters (reading or optional practice).
    var attempts: [String: Set<String>] = [:]
    var positions: [String: Int] = [:]
    var practiceDays: Set<String> = []
    var vocabulary: [String: VocabularyState] = [:]
    var evidence: [String: Int] = [:]
}
struct CompletionReceipt: Identifiable, Sendable {
    let id = UUID()
    let book: Book
    let isNew: Bool
    let total: Int
}
struct WeekDay: Identifiable { let id: String; let label: String; let practiced: Bool; let today: Bool }
