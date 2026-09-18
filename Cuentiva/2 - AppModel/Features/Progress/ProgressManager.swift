import Foundation
import Observation

@MainActor protocol ProgressFeature: AnyObject, Sendable {
    var snapshot: LearnerProgress { get }
    var loaded: Bool { get }
    var streak: Int { get }
    var week: [WeekDay] { get }
    func load() async throws
    func registerLibrary(_ books: [Book]) async throws
    func saveDailyReading(_ ids: [String], date: Date) async throws
    func recordEncounter(book: Book, sentence: Sentence) async throws
    func advanceReading(book: Book, from index: Int) async throws -> LessonAdvance
    func savePosition(book: Book, position: Int) async throws
    func complete(book: Book) async throws -> CompletionReceipt
    func completeReading(book: Book) async throws -> CompletionReceipt
    func setVocabulary(_ lemma: String, state: VocabularyState) async throws
    func setLearningLevel(_ level: LearningLevel?) async throws
    func rewardPractice(book: Book, matches: Int) async throws -> Bool
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
        self.repository = repository
        self.now = now
        self.calendar = calendar
    }
    private func dayKey(_ date: Date) -> String {
        return String(
            format: "%04d-%02d-%02d",
            calendar.component(.year, from: date), calendar.component(.month, from: date),
            calendar.component(.day, from: date))
    }
    var streak: Int {
        var day = calendar.startOfDay(for: now())
        var count = 0
        if !snapshot.practiceDays.contains(dayKey(day)) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
        }
        while snapshot.practiceDays.contains(dayKey(day)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day), previous < day else { break }
            day = previous
        }
        return count
    }
    var week: [WeekDay] {
        let today = now()
        guard let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return WeekDay(
                id: dayKey(date), label: date.formatted(.dateTime.weekday(.narrow)),
                practiced: snapshot.practiceDays.contains(dayKey(date)),
                today: calendar.isDate(date, inSameDayAs: today))
        }
    }
    func load() async throws {
        if loaded { return }
        let value = try await repository.load()
        if !loaded {
            snapshot = value
            loaded = true
        }
    }
    private func commit(_ update: (inout LearnerProgress) -> Void) async throws {
        guard loaded else { throw AppFailure.unavailable("Progress has not loaded. Please retry.") }
        guard !saving else { throw AppFailure.busy }
        saving = true
        defer { saving = false }
        var next = snapshot
        update(&next)
        try await repository.save(next)
        snapshot = next
    }
    func registerLibrary(_ books: [Book]) async throws {
        let missing = books.map(\.id).filter { snapshot.bookArrivals?[$0] == nil }
        guard !missing.isEmpty else { return }
        let arrived = now()
        try await commit { next in
            if next.bookArrivals == nil { next.bookArrivals = [:] }
            for id in missing { next.bookArrivals?[id] = arrived }
        }
    }
    func saveDailyReading(_ ids: [String], date: Date) async throws {
        guard ids.count <= 3, Set(ids).count == ids.count else { throw AppFailure.invalidBook }
        guard snapshot.dailyReadingIDs != ids || snapshot.dailyReadingDate != date else { return }
        try await commit { next in
            next.dailyReadingIDs = ids
            next.dailyReadingDate = date
        }
    }
    private func addEncounter(book: Book, sentence: Sentence, to next: inout LearnerProgress) {
        if next.bookLastRead == nil { next.bookLastRead = [:] }
        next.bookLastRead?[book.id] = now()
        if next.wordHistoryComplete == nil { next.wordHistoryComplete = next.evidence.isEmpty }
        if next.wordHistoryComplete == true, next.bookWordBaselines?[book.id] == nil,
            next.attempts[book.id, default: []].isEmpty
        {
            if next.bookWordBaselines == nil { next.bookWordBaselines = [:] }
            next.bookWordBaselines?[book.id] = next.seenWords ?? []
        }
        if next.seenWords == nil { next.seenWords = [] }
        next.seenWords?.formUnion(WordComparison.words(sentence.spanish).map(WordComparison.normalized))
        let inserted = next.attempts[book.id, default: []].insert(sentence.id).inserted
        next.practiceDays.insert(dayKey(now()))
        if inserted {
            for token in WordComparison.words(sentence.spanish) {
                let word = WordComparison.normalized(token)
                let lemma = book.vocabulary.first { $0.word == word }?.lemma ?? word
                if next.vocabulary[lemma] == nil || next.vocabulary[lemma] == .unknown {
                    next.vocabulary[lemma] = .learning
                }
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
        try await commit {
            $0.positions[book.id] = max(0, min(position, book.sentences.count - 1))
            if $0.bookLastRead == nil { $0.bookLastRead = [:] }
            $0.bookLastRead?[book.id] = now()
        }
    }
    func complete(book: Book) async throws -> CompletionReceipt {
        guard Set(book.fullText.map(\.id)).isSubset(of: snapshot.attempts[book.id, default: []]) else {
            throw AppFailure.incomplete
        }
        let isNew = !snapshot.completed.contains(book.id)
        let celebrate = !(snapshot.celebratedCompletionDays ?? []).contains(dayKey(now()))
        try await commit {
            $0.completed.insert(book.id)
            $0.positions[book.id] = 0
            if $0.celebratedCompletionDays == nil { $0.celebratedCompletionDays = [] }
            $0.celebratedCompletionDays?.insert(dayKey(now()))
        }
        return .init(
            book: book, isNew: isNew, total: snapshot.completed.count, streakCelebration: celebrate ? streak : nil)
    }
    /// The final reader action records the continuation and completion in one save.
    func completeReading(book: Book) async throws -> CompletionReceipt {
        guard Set(book.sentences.map(\.id)).isSubset(of: snapshot.attempts[book.id, default: []]) else {
            throw AppFailure.incomplete
        }
        let isNew = !snapshot.completed.contains(book.id)
        let celebrate = !(snapshot.celebratedCompletionDays ?? []).contains(dayKey(now()))
        try await commit { next in
            for sentence in book.continuation ?? [] { addEncounter(book: book, sentence: sentence, to: &next) }
            if next.celebratedCompletionDays == nil { next.celebratedCompletionDays = [] }
            next.celebratedCompletionDays?.insert(dayKey(now()))
            next.completed.insert(book.id)
            next.positions[book.id] = 0
        }
        return .init(
            book: book, isNew: isNew, total: snapshot.completed.count, streakCelebration: celebrate ? streak : nil)
    }
    func setVocabulary(_ lemma: String, state: VocabularyState) async throws {
        try await commit { $0.vocabulary[lemma] = state }
    }
    func rewardPractice(book: Book, matches: Int) async throws -> Bool {
        guard snapshot.completed.contains(book.id), matches > 0, matches <= Set(book.vocabulary.map(\.word)).count
        else { throw AppFailure.incomplete }
        let awarded = !(snapshot.rewardedBooks ?? []).contains(book.id)
        try await commit { next in
            if next.bestMatches == nil { next.bestMatches = [:] }
            let best = max(next.bestMatches?[book.id] ?? 0, matches)
            next.bestMatches?[book.id] = best
            if awarded {
                if next.rewardedBooks == nil { next.rewardedBooks = [] }
                next.rewardedBooks?.insert(book.id)
                next.doubloons = (next.doubloons ?? 0) + 1
            }
        }
        return awarded
    }
    func setLearningLevel(_ level: LearningLevel?) async throws {
        try await commit { $0.selectedLearningLevel = level }
    }
    func reset() async throws { try await commit { $0 = .init() } }
}
