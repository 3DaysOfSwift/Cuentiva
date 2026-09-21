//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor protocol ProgressFeature: AnyObject, Sendable {
    var snapshot: LearnerProgress { get }
    var revision: UUID { get }
    var loaded: Bool { get }
    var streak: Int { get }
    var canReviveStreak: Bool { get }
    var revivalNeedsBook: Bool { get }
    func reviveStreak() async throws
    var week: [WeekDay] { get }
    var dailyWelcome: DailyWelcome? { get }
    var dailyChallenge: DailyMatchChallenge? { get }
    var dailyPractice: DailyPracticeSession? { get }
    func prepareDailyPractice(books: [Book]) async throws
    func answerDailyPractice(_ choice: String, game: DailyPracticeGame, day: String) async throws -> Bool
    func stopDailyTrail(day: String) async throws
    func selectPracticeScenario(_ scenario: PracticeScenario, day: String) async throws
    @discardableResult func completeDailyGame(book: Book, day: String, words: Set<String>, elapsed: Double?) async throws -> MatchRewardReceipt?
    #if DEBUG
    func setVerbTrainingPreview(_ enabled: Bool) async throws
    #endif
    @discardableResult func performVerbTraining(_ action: VerbTrainingAction) async throws -> Bool
    func claimAutomaticLibraryCheck() async throws -> Bool
    func acknowledgeWelcome(day: String) async throws
    func acknowledgeLanguageTip(_ id: String) async throws
    func load() async throws
    func registerLibrary(_ books: [Book]) async throws
    func saveDailyReading(_ ids: [String], date: Date) async throws
    func recordEncounter(book: Book, sentence: Sentence) async throws
    func finishChapterTwo(book: Book) async throws -> Int
    func advanceReading(book: Book, from index: Int) async throws -> LessonAdvance
    func savePosition(book: Book, position: Int) async throws
    func complete(book: Book) async throws -> CompletionReceipt
    func completeReading(book: Book) async throws -> CompletionReceipt
    func setVocabulary(_ lemma: String, state: VocabularyState) async throws
    func setLearningLevel(_ level: LearningLevel?) async throws
    func recordPractice(book: Book, matches: Int, elapsed: Double?) async throws
    func installThemePack(_ pack: ThemePack) async throws
    func saveChatReply(authorID: String, conversation: ChatConversation, receiptID: UUID?, renewing: Bool) async throws -> PaidChatSession
    func checkpointChat(authorID: String, receiptID: UUID) async throws
    func clearChat(authorID: String) async throws
    func payForChat(deliver: @MainActor () -> Bool) async throws
    func reset() async throws
}
@MainActor @Observable final class ProgressManager: ProgressFeature {
    #if DEBUG
    func setVerbTrainingPreview(_ enabled: Bool) async throws {
        try await commit { $0.debugVerbTrainingEnabled = enabled }
    }
    #endif
    @discardableResult func performVerbTraining(_ action: VerbTrainingAction) async throws -> Bool {
        try await commit { next in
            guard next.verbTrainingUnlocked else { throw AppFailure.unavailable("Your Verb Training gift opens after 20 practice days.") }
            if case .claimGift = action {
                if next.practiceDays.count >= 20 { next.claimedVerbGift = true }
                return true
            }
            guard next.verbTrainingGiftOpened else { throw AppFailure.unavailable("Open your Verb Training gift first.") }
            var state = next.verbTraining ?? VerbTrainingState()
            state.refreshDay(dayKey(now()))
            switch action {
            case .claimGift: break
            case .refreshDay: break
            case .reviewCompletion(let round): try state.reviewCompletion(round: round)
            case .prepare: try state.prepare()
            case .next(let round): try state.next(after: round)
            case .select(let id): try state.select(id)
            case .choose(let word, let round, let index):
                guard try state.choose(word, round: round, index: index) else { return false }
                // Verb practice contributes to active days, not the book-completion streak.
                if next.streakDays == nil { next.streakDays = next.practiceDays }
                next.practiceDays.insert(dayKey(now()))
                recordExposure(word, to: &next)
            }
            next.verbTraining = state
            return true
        }
    }
    var dailyPractice: DailyPracticeSession? {
        guard let value = snapshot.dailyPracticeSession, value.day == dayKey(now()), value.valid else { return nil }
        return value
    }
    func prepareDailyPractice(books: [Book]) async throws {
        try await commit { next in
            let day = dayKey(now())
            if var existing = next.dailyPracticeSession, existing.day == day {
                guard existing.valid else { throw AppFailure.invalidBook }
                // Sessions from the old bundle-reward policy can have completed,
                // unpaid games. Reconcile them atomically when practice is opened.
                creditPracticeRewards(&existing, to: &next)
                next.dailyPracticeSession = existing
                return
            }
            guard next.dailyReadingDate.map({ calendar.isDate($0, inSameDayAs: now()) }) == true,
                  next.dailyReadingIDs == books.map(\.id) else { throw AppFailure.incomplete }
            next.dailyPracticeSession = try DailyPracticeSession.make(day: day, books: books)
        }
    }
    private func savePractice(_ session: inout DailyPracticeSession, to next: inout LearnerProgress) {
        if next.streakDays == nil { next.streakDays = next.practiceDays }
        next.practiceDays.insert(dayKey(now()))
        creditPracticeRewards(&session, to: &next)
        next.dailyPracticeSession = session
    }
    private func creditPracticeRewards(_ session: inout DailyPracticeSession, to next: inout LearnerProgress) {
        let credited = session.creditedGames
        let newlyEarned = session.completed.subtracting(credited)
        next.doubloons = (next.doubloons ?? 0) + newlyEarned.count
        session.rewardedGames = credited.union(newlyEarned)
        session.rewarded = session.creditedGames.count == DailyPracticeGame.allCases.count
    }
    func answerDailyPractice(_ choice: String, game: DailyPracticeGame, day: String) async throws -> Bool {
        try await commit { next in
            guard var session = next.dailyPracticeSession, session.day == day, day == dayKey(now()), session.valid else {
                throw AppFailure.unavailable("A new practice day has started. Return to Today.")
            }
            let exposed = game == .sentenceBuilder ? session.builderPhrase.spanish : choice
            let accepted = try session.choose(choice, game: game)
            if accepted {
                recordExposure(exposed, to: &next)
            }
            savePractice(&session, to: &next)
            return accepted
        }
    }
    func stopDailyTrail(day: String) async throws {
        try await commit { next in
            guard var session = next.dailyPracticeSession, session.day == day, day == dayKey(now()),
                  session.valid, !session.completed.contains(.sentenceTrail), session.trailScore > 0 else { throw AppFailure.incomplete }
            session.completed.insert(.sentenceTrail)
            savePractice(&session, to: &next)
        }
    }
    func selectPracticeScenario(_ scenario: PracticeScenario, day: String) async throws {
        try await commit { next in
            guard var session = next.dailyPracticeSession, session.day == day, day == dayKey(now()), session.valid else { throw AppFailure.incomplete }
            try session.selectScenario(scenario)
            next.dailyPracticeSession = session
        }
    }
    private func recordExposure(_ text: String, to next: inout LearnerProgress) {
        if next.seenWords == nil { next.seenWords = [] }
        next.seenWords?.formUnion(WordComparison.words(text).map(WordComparison.normalized))
        if next.wordExposureHistory == nil { next.wordExposureHistory = [:] }
        next.wordExposureHistory?[dayKey(now())] = next.seenWords?.count ?? 0
    }
    private(set) var revision = UUID()
    private(set) var snapshot = LearnerProgress() {
        didSet { revision = UUID() }
    }
    private(set) var loaded = false
    @ObservationIgnored private var loadingTask: Task<Void, Error>?
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
    var dailyChallenge: DailyMatchChallenge? {
        guard let challenge = snapshot.dailyMatchChallenge, challenge.day == dayKey(now()),
              challenge.bookIDs.count == 3,
              Set(challenge.bookIDs).isSubset(of: snapshot.completed) else { return nil }
        return challenge
    }
    @discardableResult func completeDailyGame(book: Book, day: String, words: Set<String>, elapsed: Double? = nil) async throws -> MatchRewardReceipt? {
        try await commit { next in
            guard var challenge = next.dailyMatchChallenge,
                  day == dayKey(now()), challenge.day == day,
                  challenge.bookIDs.count == 3, challenge.bookIDs.contains(book.id),
                  Set(challenge.bookIDs).isSubset(of: next.completed),
                  words.count == DailyMatchChallenge.pairCount,
                  words.isSubset(of: Set(book.vocabulary.map(\.word))),
                  words.allSatisfy({ !(book.matchGlossary?[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) })
            else { throw AppFailure.unavailable("This daily challenge is no longer available.") }
            if let elapsed { try next.recordMatchTime(elapsed, bookID: book.id, daily: true) }
            challenge.completedBookIDs.insert(book.id)
            if next.bestMatches == nil { next.bestMatches = [:] }
            let best = max(next.bestMatches?[book.id] ?? 0, words.count)
            next.bestMatches?[book.id] = best
            var receipt: MatchRewardReceipt?
            var paid = challenge.paidBookIDs
            if paid.insert(book.id).inserted {
                let previousBalance = next.availableChatCoins
                next.doubloons = (next.doubloons ?? 0) + 1
                receipt = MatchRewardReceipt(previousBalance: previousBalance, balance: next.availableChatCoins)
            }
            challenge.rewardedBookIDs = paid
            challenge.rewarded = Set(challenge.bookIDs).isSubset(of: paid)
            next.dailyMatchChallenge = challenge
            return receipt
        }
    }
    var dailyWelcome: DailyWelcome? {
        let day = dayKey(now())
        guard loaded, snapshot.lastWelcomeDay != day else { return nil }
        return DailyWelcome(day: day, streak: streak,
            practicedToday: snapshot.qualifyingStreakDays.contains(day),
            returningReader: !snapshot.practiceDays.isEmpty)
    }
    func claimAutomaticLibraryCheck() async throws -> Bool {
        try await commit { next in
            let today = dayKey(now())
            guard next.lastAutomaticLibraryCheckDay != today else { return false }
            next.lastAutomaticLibraryCheckDay = today
            return true
        }
    }
    func acknowledgeWelcome(day: String) async throws {
        guard day == dayKey(now()) else { return }
        try await commit { next in
            next.lastWelcomeDay = day
            var tips = next.languageTips ?? LanguageTipProgress()
            tips.visit(day: day, termIDs: LanguageTermsManager.terms.map(\.id))
            next.languageTips = tips
        }
    }
    func acknowledgeLanguageTip(_ id: String) async throws {
        try await commit { next in
            guard var tips = next.languageTips else { throw AppFailure.incomplete }
            try tips.acknowledge(id)
            next.languageTips = tips
        }
    }
    var streak: Int { streak(in: snapshot) }
    private func streak(in value: LearnerProgress) -> Int {
        var day = calendar.startOfDay(for: now())
        let days = value.qualifyingStreakDays
        var count = 0
        if !days.contains(dayKey(day)) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
        }
        while true {
            if days.contains(dayKey(day)) { count += 1 }
            else if count == 0 || !(value.revivedStreakDays ?? []).contains(dayKey(day)) { break }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day), previous < day else { break }
            day = previous
        }
        return count
    }
    private func missedDay(in value: LearnerProgress) -> String? {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now()),
              let before = calendar.date(byAdding: .day, value: -2, to: now()),
              value.qualifyingStreakDays.contains(dayKey(before)),
              !value.qualifyingStreakDays.contains(dayKey(yesterday)),
              !(value.revivedStreakDays ?? []).contains(dayKey(yesterday)) else { return nil }
        return dayKey(yesterday)
    }
    var canReviveStreak: Bool { loaded && missedDay(in: snapshot) != nil }
    var revivalNeedsBook: Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now()) else { return false }
        return (snapshot.revivedStreakDays ?? []).contains(dayKey(yesterday))
            && !snapshot.qualifyingStreakDays.contains(dayKey(now()))
    }
    func reviveStreak() async throws {
        try await commit { next in
            guard let missed = missedDay(in: next) else {
                throw AppFailure.unavailable("A streak can only be revived the day after one missed day.")
            }
            guard (next.doubloons ?? 0) >= 4 else {
                throw AppFailure.unavailable("You need 4 doubloons to revive your streak.")
            }
            next.doubloons = (next.doubloons ?? 0) - 4
            if next.revivedStreakDays == nil { next.revivedStreakDays = [] }
            next.revivedStreakDays?.insert(missed)
            // Reading before paying is also valid; award today's bonus exactly once.
            if next.qualifyingStreakDays.contains(dayKey(now())) { _ = awardStreakBonus(to: &next) }
        }
    }
    private func awardStreakBonus(to next: inout LearnerProgress) -> Int {
        let today = dayKey(now())
        guard streak(in: next) >= 2, !(next.rewardedStreakDays ?? []).contains(today) else { return 0 }
        if next.rewardedStreakDays == nil { next.rewardedStreakDays = [] }
        next.rewardedStreakDays?.insert(today)
        next.doubloons = (next.doubloons ?? 0) + 1
        return 1
    }
    var week: [WeekDay] {
        let today = now()
        guard let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return WeekDay(
                id: dayKey(date), label: date.formatted(.dateTime.weekday(.narrow)),
                practiced: snapshot.qualifyingStreakDays.contains(dayKey(date)),
                today: calendar.isDate(date, inSameDayAs: today),
                revived: (snapshot.revivedStreakDays ?? []).contains(dayKey(date)))
        }
    }
    /// Launch and member activation share one read. Cancelling a caller does
    /// not cancel the feature's read or leave another caller without progress.
    func load() async throws {
        if loaded { return }
        if let loadingTask { return try await loadingTask.value }
        let task = Task {
            defer { loadingTask = nil }
            let value = try await repository.load()
            snapshot = value
            loaded = true
        }
        loadingTask = task
        try await task.value
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
            let day = dayKey(date)
            if ids.count == 3 && next.dailyMatchChallenge?.day != day {
                next.dailyMatchChallenge = DailyMatchChallenge(day: day, bookIDs: ids)
            }
        }
    }
    private func addEncounter(book: Book, sentence: Sentence, to next: inout LearnerProgress) {
        if next.streakDays == nil { next.streakDays = next.practiceDays }
        if next.bookLastRead == nil { next.bookLastRead = [:] }
        next.bookLastRead?[book.id] = now()
        if next.wordHistoryComplete == nil { next.wordHistoryComplete = next.evidence.isEmpty }
        if next.wordHistoryComplete == true, next.bookWordBaselines?[book.id] == nil,
            next.attempts[book.id, default: []].isEmpty
        {
            if next.bookWordBaselines == nil { next.bookWordBaselines = [:] }
            next.bookWordBaselines?[book.id] = next.seenWords ?? []
        }
        recordExposure(sentence.spanish, to: &next)
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
    /// Commit chapter-two exposure and its resume boundary together.
    func finishChapterTwo(book: Book) async throws -> Int {
        try await commit { next in
            guard Set(book.sentences.map(\.id)).isSubset(of: next.attempts[book.id, default: []]) else {
                throw AppFailure.incomplete
            }
            for sentence in book.continuation ?? [] { addEncounter(book: book, sentence: sentence, to: &next) }
            next.positions[book.id] = book.chapterThreeStart
        }
        return book.chapterThreeStart
    }
    /// Sentence encounters and resume position are committed together.
    func advanceReading(book: Book, from index: Int) async throws -> LessonAdvance {
        guard book.fullText.indices.contains(index),
              index < book.sentences.count || index >= book.chapterThreeStart else { throw AppFailure.invalidBook }
        let last = index == book.fullText.count - 1
        try await commit { next in
            addEncounter(book: book, sentence: book.fullText[index], to: &next)
            next.positions[book.id] = index + 1
        }
        if index == book.sentences.count - 1, !(book.continuation ?? []).isEmpty { return .fullReading }
        return last ? .bookFinished : .position(index + 1)
    }
    func savePosition(book: Book, position: Int) async throws {
        try await commit {
            $0.positions[book.id] = max(0, min(position, book.fullText.count - 1))
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
            let required = includingContinuation && (book.ending ?? []).isEmpty ? book.sentences : book.fullText
            guard Set(required.map(\.id)).isSubset(of: next.attempts[book.id, default: []]) else {
                throw AppFailure.incomplete
            }
            if includingContinuation {
                for sentence in book.continuation ?? [] { addEncounter(book: book, sentence: sentence, to: &next) }
            }
            if next.streakDays == nil { next.streakDays = next.practiceDays }
            next.streakDays?.insert(dayKey(now()))
            next.practiceDays.insert(dayKey(now()))
            let streakBonus = awardStreakBonus(to: &next)
            if next.earnedStreakTheme != true && streak(in: next) >= 10 { next.earnedStreakTheme = true }
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
                streakBonus: streakBonus, streakCelebration: celebrate ? streak(in: next) : nil, streakThemeGift: streakGift ? .vip : nil)
        }
    }
    func setVocabulary(_ lemma: String, state: VocabularyState) async throws {
        try await commit { $0.vocabulary[lemma] = state }
    }
    func recordPractice(book: Book, matches: Int, elapsed: Double? = nil) async throws {
        try await commit { next in
            guard next.completed.contains(book.id), matches > 0, matches <= Set(book.vocabulary.map(\.word)).count
            else { throw AppFailure.incomplete }
            if next.bestMatches == nil { next.bestMatches = [:] }
            if let elapsed {
                guard matches == Set(book.vocabulary.map(\.word)).count else { throw AppFailure.incomplete }
                try next.recordMatchTime(elapsed, bookID: book.id, daily: false)
            }
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
    func saveChatReply(authorID: String, conversation: ChatConversation, receiptID: UUID?, renewing: Bool) async throws -> PaidChatSession {
        try await commit { next in
            guard next.chatUnlocked, !authorID.isEmpty else { throw AppFailure.incomplete }
            let previous = next.chatSessions?[authorID]
            guard previous?.receiptID == receiptID else { throw AppFailure.unavailable("This conversation changed. Reopen it to continue.") }
            let count: Int
            let token: UUID
            if renewing {
                guard next.availableChatCoins > 0 else { throw AppFailure.unavailable("Complete another story to earn a doubloon.") }
                if next.pendingChatAdmission == true { next.pendingChatAdmission = false }
                else { next.doubloons = (next.doubloons ?? 0) - 1 }
                count = 1
                token = UUID()
            } else {
                guard let previous, previous.sentMessages > 0,
                      previous.sentMessages < ChatLimits.messagesPerCoin else {
                    throw AppFailure.unavailable("This chat allowance is complete. Slide to continue for 1 doubloon.")
                }
                count = previous.sentMessages + 1
                token = previous.receiptID
            }
            var saved = conversation
            saved.messages = Array(saved.messages.suffix(ChatLimits.savedMessages))
            // An interrupted in-flight message remains visible and can be retried on return.
            for index in saved.messages.indices where saved.messages[index].delivery == .pending {
                saved.messages[index].delivery = .failed
            }
            let date = now()
            let session = PaidChatSession(receiptID: token, conversation: saved, sentMessages: count,
                lastActivity: date, resumeUntil: date.addingTimeInterval(ChatLimits.returnWindow))
            if next.chatSessions == nil { next.chatSessions = [:] }
            next.chatSessions?[authorID] = session
            return session
        }
    }
    func checkpointChat(authorID: String, receiptID: UUID) async throws {
        try await commit { next in
            guard var session = next.chatSessions?[authorID], session.receiptID == receiptID,
                  session.sentMessages < ChatLimits.messagesPerCoin else { return }
            session.lastActivity = now()
            session.resumeUntil = session.lastActivity.addingTimeInterval(ChatLimits.returnWindow)
            next.chatSessions?[authorID] = session
        }
    }
    func clearChat(authorID: String) async throws {
        try await commit { $0.chatSessions?[authorID] = nil }
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
