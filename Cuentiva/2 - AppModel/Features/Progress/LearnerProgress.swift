import Foundation

enum VocabularyState: String, Codable, CaseIterable, Sendable { case unknown, learning, known }
enum LearningLevel: String, Codable, CaseIterable, Sendable { case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1", c2 = "C2" }
struct LearnerProgress: Codable, Sendable, Equatable {
    /// Shared across all targets; only distinct, saved completions unlock writing.
    var chatUnlocked: Bool { completed.count >= ReadingMilestones.chatOfferBookCount }
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
    var lastWelcomeDay: String? = nil
    var schemaVersion = 1
    var selectedLearningLevel: LearningLevel? = nil
    var completed: Set<String> = []
    // Legacy storage key: records sentence encounters (reading or optional practice).
    var attempts: [String: Set<String>] = [:]
    // Optional for backward-compatible decoding of existing learner files.
    var bookArrivals: [String: Date]? = nil
    var bookLastRead: [String: Date]? = nil
    var dailyReadingDate: Date? = nil
    var dailyReadingIDs: [String]? = nil
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
    var streakCelebration: Int? = nil
    var streakThemeGift: ThemePack? = nil
    var unlocksChat: Bool { isNew && total == ReadingMilestones.chatOfferBookCount }
    var offersChat: Bool { total >= ReadingMilestones.chatOfferBookCount }
    var unlocksWriting: Bool { isNew && total == ReadingMilestones.writingBookCount }
    var celebratesHundredBooks: Bool { isNew && total == ReadingMilestones.honouredReaderBookCount }
    var themePackGift: ThemePack? {
        isNew ? ThemePack.allCases.first { $0.requiredBooks == total } : nil
    }
    var requestsReview: Bool { isNew && total == ReadingMilestones.reviewBookCount && streakThemeGift == nil }
}
struct WeekDay: Identifiable { let id: String; let label: String; let practiced: Bool; let today: Bool }
