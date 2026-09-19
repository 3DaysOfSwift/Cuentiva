import Foundation
import Observation

@MainActor protocol ProgressFeature: AnyObject, Sendable {
    var snapshot: LearnerProgress { get }
    var revision: UUID { get }
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
    func recordPractice(book: Book, matches: Int) async throws
    func installThemePack(_ pack: ThemePack) async throws
    func payForChat(deliver: @MainActor () -> Bool) async throws
    func reset() async throws
}
@MainActor @Observable final class ProgressManager: ProgressFeature {
    private(set) var revision = UUID()
    private(set) var snapshot = LearnerProgress() {
        didSet { revision = UUID() }
    }
    private(set) var loaded = false
    @ObservationIgnored private var saving = false
    @ObservationIgnored private var waitingSaves: [CheckedContinuation<Void, Never>] = []

    /// FIFO ownership spans the repository suspension. Each operation reads the
    /// latest committed snapshot only after acquiring its turn.
    var queuedSaveCount: Int { waitingSaves.count }
    private func acquireSave() async {
        if !saving { saving = true; return }
        await withCheckedContinuation { waitingSaves.append($0) }
    }
    private func releaseSave() {
        if waitingSaves.isEmpty { saving = false }
        else { waitingSaves.removeFirst().resume() }
    }
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
    var streak: Int { streak(in: snapshot) }
    private func streak(in value: LearnerProgress) -> Int {
        var day = calendar.startOfDay(for: now())
        var count = 0
        if !value.practiceDays.contains(dayKey(day)) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
        }
        while value.practiceDays.contains(dayKey(day)) {
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
    @discardableResult
    private func commit<Value>(_ update: (inout LearnerProgress) throws -> Value) async throws -> Value {
        await acquireSave()
        defer { releaseSave() }
        try Task.checkCancellation()
        guard loaded else { throw AppFailure.unavailable("Progress has not loaded. Please retry.") }
        var next = snapshot
        let result = try update(&next)
        if next.earnedStreakTheme != true && streak(in: next) >= 10 { next.earnedStreakTheme = true }
        if next != snapshot { try await repository.save(next) }
        // A successful save must be published even if cancellation arrived during I/O.
        snapshot = next
        return result
    }
    func registerLibrary(_ books: [Book]) async throws {
        let arrived = now()
        try await commit { next in
            let missing = books.map(\.id).filter { next.bookArrivals?[$0] == nil }
            if next.bookArrivals == nil { next.bookArrivals = [:] }
            for id in missing { next.bookArrivals?[id] = arrived }
        }
    }
    func saveDailyReading(_ ids: [String], date: Date) async throws {
        guard ids.count <= 3, Set(ids).count == ids.count else { throw AppFailure.invalidBook }
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
        try await finish(book: book, includingContinuation: false)
    }
    /// The final reader action records the continuation and completion in one save.
    func completeReading(book: Book) async throws -> CompletionReceipt {
        try await finish(book: book, includingContinuation: true)
    }
    private func finish(book: Book, includingContinuation: Bool) async throws -> CompletionReceipt {
        try await commit { next in
            let required = includingContinuation ? book.sentences : book.fullText
            guard Set(required.map(\.id)).isSubset(of: next.attempts[book.id, default: []]) else {
                throw AppFailure.incomplete
            }
            if includingContinuation {
                for sentence in book.continuation ?? [] { addEncounter(book: book, sentence: sentence, to: &next) }
            }
            let streakGift = next.earnedStreakTheme == true && next.celebratedStreakTheme != true
            let isNew = !next.completed.contains(book.id)
            let celebrate = !(next.celebratedCompletionDays ?? []).contains(dayKey(now()))
            if streakGift { next.celebratedStreakTheme = true }
            if isNew {
                next.doubloons = (next.doubloons ?? 0) + 1
                if next.rewardedBooks == nil { next.rewardedBooks = [] }
                next.rewardedBooks?.insert(book.id)
            }
            next.completed.insert(book.id)
            next.positions[book.id] = 0
            if next.celebratedCompletionDays == nil { next.celebratedCompletionDays = [] }
            next.celebratedCompletionDays?.insert(dayKey(now()))
            return CompletionReceipt(book: book, isNew: isNew, total: next.completed.count,
                streakCelebration: celebrate ? streak(in: next) : nil, streakThemeGift: streakGift ? .vip : nil)
        }
    }
    func setVocabulary(_ lemma: String, state: VocabularyState) async throws {
        try await commit { $0.vocabulary[lemma] = state }
    }
    func recordPractice(book: Book, matches: Int) async throws {
        try await commit { next in
            guard next.completed.contains(book.id), matches > 0, matches <= Set(book.vocabulary.map(\.word)).count
            else { throw AppFailure.incomplete }
            if next.bestMatches == nil { next.bestMatches = [:] }
            let best = max(next.bestMatches?[book.id] ?? 0, matches)
            next.bestMatches?[book.id] = best
        }
    }
    func setLearningLevel(_ level: LearningLevel?) async throws {
        try await commit { $0.selectedLearningLevel = level }
    }
    /// Persist an admission before delivering a reply. An unused admission remains
    /// redeemable after dismissal, cancellation, a failed settlement, or relaunch.
    /// Delivery is synchronous on MainActor, so session validity cannot change
    /// between accepting the admission and publishing its reply.
    func payForChat(deliver: @MainActor () -> Bool) async throws {
        await acquireSave()
        defer { releaseSave() }
        try Task.checkCancellation()
        guard loaded else { throw AppFailure.unavailable("Progress has not loaded. Please retry.") }
        if snapshot.pendingChatAdmission != true {
            guard (snapshot.doubloons ?? 0) > 0 else {
                throw AppFailure.unavailable("Complete another story to earn a doubloon for a new chat.")
            }
            var next = snapshot
            next.doubloons = (next.doubloons ?? 0) - 1
            next.pendingChatAdmission = true
            try await repository.save(next)
            snapshot = next
        }
        guard !Task.isCancelled, deliver() else { throw CancellationError() }
        var settled = snapshot
        settled.pendingChatAdmission = false
        try await repository.save(settled)
        snapshot = settled
    }
    func installThemePack(_ pack: ThemePack) async throws {
        try await commit { next in
            if next.hasInstalled(pack) { return }
            guard next.earnedThemePacks.contains(pack) else {
                throw AppFailure.unavailable("This theme gift hasn’t been earned yet.")
            }
            if next.installedThemePacks == nil { next.installedThemePacks = [] }
            next.installedThemePacks?.insert(pack.rawValue)
        }
    }
    func reset() async throws {
        try await commit {
            let earnedStreak = $0.earnedStreakTheme
            let celebratedStreak = $0.celebratedStreakTheme
            let installed = $0.installedThemePacks
            $0 = .init()
            $0.installedThemePacks = installed
            $0.earnedStreakTheme = earnedStreak
            $0.celebratedStreakTheme = celebratedStreak
        }
    }
}
