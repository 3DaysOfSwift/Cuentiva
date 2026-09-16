import Foundation
import Observation

@MainActor protocol ProgressFeature: AnyObject, Sendable {
    var snapshot: LearnerProgress { get }
    var loaded: Bool { get }
    var streak: Int { get }
    var week: [WeekDay] { get }
    func load() async throws
    func recordEncounter(book: Book, sentence: Sentence) async throws
    func advanceReading(book: Book, from index: Int) async throws -> LessonAdvance
    func savePosition(book: Book, position: Int) async throws
    func complete(book: Book) async throws -> CompletionReceipt
    func completeReading(book: Book) async throws -> CompletionReceipt
    func setVocabulary(_ lemma: String, state: VocabularyState) async throws
    func reset() async throws
}
@MainActor @Observable final class ProgressManager: ProgressFeature {
    private(set) var snapshot = LearnerProgress()
    private(set) var loaded = false
    private var saving = false
    private let repository: any ProgressRepository
    private let now: () -> Date
    private let calendar: Calendar
    init(repository: any ProgressRepository, now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.repository = repository; self.now = now; self.calendar = calendar
    }
    private func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    var streak: Int {
        var day = calendar.startOfDay(for: now()), count = 0
        if !snapshot.practiceDays.contains(dayKey(day)) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        while snapshot.practiceDays.contains(dayKey(day)) {
            count += 1; day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
    var week: [WeekDay] {
        let today = now(), start = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            return WeekDay(id: dayKey(date), label: date.formatted(.dateTime.weekday(.narrow)), practiced: snapshot.practiceDays.contains(dayKey(date)), today: calendar.isDate(date, inSameDayAs: today))
        }
    }
    func load() async throws {
        if loaded { return }
        let value = try await repository.load()
        if !loaded { snapshot = value; loaded = true }
    }
    private func commit(_ update: (inout LearnerProgress) -> Void) async throws {
        guard loaded else { throw AppFailure.unavailable("Progress has not loaded. Please retry.") }
        guard !saving else { throw AppFailure.busy }
        saving = true; defer { saving = false }
        var next = snapshot; update(&next)
        try await repository.save(next)
        snapshot = next
    }
    private func addEncounter(book: Book, sentence: Sentence, to next: inout LearnerProgress) {
        let inserted = next.attempts[book.id, default: []].insert(sentence.id).inserted
        next.practiceDays.insert(dayKey(now()))
        if inserted {
            for token in WordComparison.words(sentence.spanish) {
                let word = WordComparison.normalized(token)
                let lemma = book.vocabulary.first { $0.word == word }?.lemma ?? word
                if next.vocabulary[lemma] == nil || next.vocabulary[lemma] == .unknown { next.vocabulary[lemma] = .learning }
                next.evidence[lemma, default: 0] += 1
            }
        }
    }
    func recordEncounter(book: Book, sentence: Sentence) async throws {
        try await commit { addEncounter(book: book, sentence: sentence, to: &$0) }
    }
    /// Reading is the core activity. One atomic write records the encounter,
    /// next position. Every book enters the full-reader stage before completion.
    func advanceReading(book: Book, from index: Int) async throws -> LessonAdvance {
        guard book.sentences.indices.contains(index) else { throw AppFailure.invalidBook }
        let last = index == book.sentences.count - 1
        try await commit { next in
            addEncounter(book: book, sentence: book.sentences[index], to: &next)
            next.positions[book.id] = index + 1
        }
        return last ? .fullReading : .position(index + 1)
    }
    func savePosition(book: Book, position: Int) async throws {
        try await commit { $0.positions[book.id] = max(0, min(position, book.sentences.count - 1)) }
    }
    func complete(book: Book) async throws -> CompletionReceipt {
        guard Set(book.fullText.map(\.id)).isSubset(of: snapshot.attempts[book.id, default: []]) else { throw AppFailure.incomplete }
        let isNew = !snapshot.completed.contains(book.id)
        try await commit { $0.completed.insert(book.id); $0.positions[book.id] = 0 }
        return .init(book: book, isNew: isNew, total: snapshot.completed.count)
    }
    /// The final reader action records the continuation and completion in one save.
    func completeReading(book: Book) async throws -> CompletionReceipt {
        guard Set(book.sentences.map(\.id)).isSubset(of: snapshot.attempts[book.id, default: []]) else { throw AppFailure.incomplete }
        let isNew = !snapshot.completed.contains(book.id)
        try await commit { next in
            for sentence in book.continuation ?? [] { addEncounter(book: book, sentence: sentence, to: &next) }
            next.completed.insert(book.id)
            next.positions[book.id] = 0
        }
        return .init(book: book, isNew: isNew, total: snapshot.completed.count)
    }
    func setVocabulary(_ lemma: String, state: VocabularyState) async throws { try await commit { $0.vocabulary[lemma] = state } }
    func reset() async throws { try await commit { $0 = .init() } }
}
