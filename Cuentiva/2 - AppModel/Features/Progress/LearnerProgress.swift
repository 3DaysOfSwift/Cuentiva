//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

enum VocabularyState: String, Codable, CaseIterable, Sendable { case unknown, learning, known }
enum LearningLevel: String, Codable, CaseIterable, Sendable { case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1", c2 = "C2" }
struct LearnerProgress: Codable, Sendable, Equatable {
    /// Shared across all targets; only distinct, saved completions unlock writing.
    var chatUnlocked: Bool { completed.count >= ReadingMilestones.chatOfferBookCount }
    func canOfferChat(onSupportedDevice supported: Bool) -> Bool { supported && chatUnlocked }
    var writingUnlocked: Bool { completed.count >= ReadingMilestones.writingBookCount }
    var isVIP: Bool { completed.count >= ReadingMilestones.honouredReaderBookCount }
    var readerBadges: [ReaderBadge] {
        isVIP ? ReaderBadge.allCases : []
    }
    func nextCompletionNumber(for bookID: String) -> Int? {
        completed.contains(bookID) ? nil : completed.count + 1
    }
    var earnedStreakTheme: Bool? = nil
    var celebratedStreakTheme: Bool? = nil
    var installedThemePacks: Set<String>? = nil
    var earnedThemePacks: [ThemePack] {
        ThemePack.allCases.filter { pack in
            if let threshold = pack.requiredBooks { return completed.count >= threshold }
            return earnedStreakTheme == true
        }
    }
    func hasInstalled(_ pack: ThemePack) -> Bool { installedThemePacks?.contains(pack.rawValue) == true }
    var availableThemes: [ColourThemeID] {
        [.library, .midnight] + ThemePack.allCases.filter(hasInstalled).flatMap(\.themes)
    }
    var claimedVerbGift: Bool? = nil
    var verbTraining: VerbTrainingState? = nil
    var debugVerbTrainingEnabled: Bool? = nil
    var verbTrainingPreview: Bool {
        #if DEBUG
        debugVerbTrainingEnabled == true
        #else
        false
        #endif
    }
    var verbTrainingGiftOpened: Bool { claimedVerbGift == true || verbTrainingPreview }
    var verbTrainingUnlocked: Bool { verbTrainingGiftOpened || practiceDays.count >= 20 }
    var dailyPracticeSession: DailyPracticeSession? = nil
    var wordExposureHistory: [String: Int]? = nil
    var lastAutomaticLibraryCheckDay: String? = nil
    var lastWelcomeDay: String? = nil
    var schemaVersion = 1
    var selectedLearningLevel: LearningLevel? = nil
    var completed: Set<String> = []
    // Legacy storage key: records sentence encounters (reading or optional practice).
    var attempts: [String: Set<String>] = [:]
    // Optional for backward-compatible decoding of existing learner files.
    var bookArrivals: [String: Date]? = nil
    var bookLastRead: [String: Date]? = nil
    var dailyMatchChallenge: DailyMatchChallenge? = nil
    var dailyReadingDate: Date? = nil
    var dailyReadingIDs: [String]? = nil
    var positions: [String: Int] = [:]
    var practiceDays: Set<String> = []
    // Nil preserves pre-upgrade streak history until the next reading action.
    var streakDays: Set<String>? = nil
    var revivedStreakDays: Set<String>? = nil
    var rewardedStreakDays: Set<String>? = nil
    var qualifyingStreakDays: Set<String> { streakDays ?? practiceDays }
    var vocabulary: [String: VocabularyState] = [:]
    var seenWords: Set<String>? = nil
    var wordHistoryComplete: Bool? = nil
    var bookWordBaselines: [String: Set<String>]? = nil
    var celebratedCompletionDays: Set<String>? = nil
    var rewardedBooks: Set<String>? = nil
    var bestMatches: [String: Int]? = nil
    var bestDailyMatchTimes: [String: Double]?
    var bestFullMatchTimes: [String: Double]?

    mutating func recordMatchTime(_ seconds: Double, bookID: String, daily: Bool) throws {
        guard seconds.isFinite, seconds > 0 else { throw AppFailure.incomplete }
        if daily {
            let best = min(bestDailyMatchTimes?[bookID] ?? seconds, seconds)
            if bestDailyMatchTimes == nil { bestDailyMatchTimes = [:] }
            bestDailyMatchTimes?[bookID] = best
        } else {
            let best = min(bestFullMatchTimes?[bookID] ?? seconds, seconds)
            if bestFullMatchTimes == nil { bestFullMatchTimes = [:] }
            bestFullMatchTimes?[bookID] = best
        }
    }
    var chatSessions: [String: PaidChatSession]? = nil
    var doubloons: Int? = nil
    /// A paid first reply that has not yet been delivered. Counts as one usable coin.
    var pendingChatAdmission: Bool? = nil
    var availableChatCoins: Int { (doubloons ?? 0) + (pendingChatAdmission == true ? 1 : 0) }
    var evidence: [String: Int] = [:]
}
struct CompletionReceipt: Identifiable, Sendable {
    let id = UUID()
    let book: Book
    let isNew: Bool
    let total: Int
    var streakBonus = 0
    var streakCelebration: Int? = nil
    var streakThemeGift: ThemePack? = nil
    var unlocksChat: Bool { isNew && total == ReadingMilestones.chatOfferBookCount }
    var offersChat: Bool { total >= ReadingMilestones.chatOfferBookCount }
    func offersChatGift(onSupportedDevice supported: Bool) -> Bool { supported && unlocksChat }
    var unlocksWriting: Bool { isNew && total == ReadingMilestones.writingBookCount }
    var celebratesHundredBooks: Bool { isNew && total == ReadingMilestones.honouredReaderBookCount }
    var themePackGift: ThemePack? {
        isNew ? ThemePack.allCases.first { $0.requiredBooks == total } : nil
    }
    var requestsReview: Bool { isNew && total == ReadingMilestones.reviewBookCount && streakThemeGift == nil }
}
struct WeekDay: Identifiable { let id: String; let label: String; let practiced: Bool; let today: Bool; var revived = false }
