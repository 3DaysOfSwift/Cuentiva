import Foundation
import OSLog
import Observation

@MainActor @Observable final class RootViewModel {
    private(set) var dailyWelcome: DailyWelcomeViewModel?
    let today: HomeViewModel
    private let progress: any ProgressFeature
    var chatUnlocked: Bool { progress.snapshot.canOfferChat(onSupportedDevice: AppleChatGenerator.supportsDevice) }
    var writingUnlocked: Bool { progress.snapshot.writingUnlocked }
    private let purchases: any PurchaseFeature
    private let library: any LibraryFeature
    @ObservationIgnored private var loadingTask: Task<Void, Never>?
    private var hasEnteredBackground = false
    private var starting = false
    private var lastAutomaticSync: Date?
    private let logger = Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "Launch")
    private let fantasy: any FantasyFeature
    private var checkedIntroduction = false
    var showingStoryteller = false
    var ready = false
    private(set) var onboardingReady = false
    var canShowContent: Bool {
        !checkingAccess && (hasAccess ? ready : (onboardingReady || ready))
    }
    var error: String?
    var hasAccess: Bool { purchases.hasAccess }
    init(
        purchases: any PurchaseFeature = AppModel.shared.purchases,
        library: any LibraryFeature = AppModel.shared.library,
        progress: any ProgressFeature = AppModel.shared.progress, fantasy: any FantasyFeature = AppModel.shared.fantasy
    ) {
        today = HomeViewModel(library: library, progress: progress)
        self.progress = progress
        self.fantasy = fantasy
        self.purchases = purchases
        self.library = library
    }
    /// Launch has one owner. Local data and StoreKit can finish independently;
    /// catalogue updates are prepared only after the initial work has completed.
    func start() async {
        guard !starting else { return }
        starting = true
        defer { starting = false }
        async let onboarding: Void = loadIntroduction()
        await refreshPurchases()
        if hasAccess && !checkingAccess { await load() }
        await onboarding
        await syncLibrary()
    }

    private func loadIntroduction() async {
        let started = Date()
        do {
            // Welcome content has no dependency on the user's database.
            // Onboarding prepares progress after its first screen is mounted.
            try await library.loadIntroduction()
            onboardingReady = true
            logger.info("Onboarding ready in \(Date().timeIntervalSince(started), privacy: .public) seconds")
        } catch { self.error = error.localizedDescription }
    }

    private func prepareWelcome() {
        guard hasAccess, !checkingAccess, let welcome = progress.dailyWelcome else { return }
        guard dailyWelcome?.welcome.day != welcome.day else { return }
        dailyWelcome = DailyWelcomeViewModel(welcome: welcome, progress: progress)
    }

    func beginDay() async {
        guard ready, hasAccess, !checkingAccess, let welcome = dailyWelcome else { return }
        guard await welcome.beginDay(), dailyWelcome === welcome else { return }
        // A suspended app may be welcoming a new calendar day. Prepare that
        // day's selection before fading back to the retained Today screen.
        while hasAccess && !checkingAccess && !Task.isCancelled {
            if await today.refresh() {
                guard dailyWelcome === welcome, hasAccess, !checkingAccess else { return }
                today.focusNextRead()
                dailyWelcome = nil
                showingStoryteller = checkedIntroduction && writingUnlocked && !fantasy.introductionSeen
                return
            }
        }
    }

    func enteredBackground() { hasEnteredBackground = true }

    func becameActive() async {
        // The first active event belongs to start(), not a second launch check.
        guard hasEnteredBackground else { return }
        hasEnteredBackground = false
        await refreshPurchases()
        await accessChanged()
    }

    var checkingAccess: Bool { purchases.checking }
    func refreshPurchases() async { await purchases.refresh() }
    /// Also handles a purchase/restore made while onboarding is visible.
    func accessChanged() async {
        guard !checkingAccess else { return }
        guard hasAccess else { ready = false; showingStoryteller = false; dailyWelcome = nil; return }
        await load()
        prepareWelcome()
        await syncLibrary()
    }
    func syncLibrary() async {
        guard hasAccess, !checkingAccess, ready, !library.syncing else { return }
        // Initial appearance and scene activation can arrive together. Automatic
        // checks are coalesced; Settings still offers an explicit retry.
        let now = Date()
        guard lastAutomaticSync.map({ now.timeIntervalSince($0) >= 3600 }) ?? true else { return }
        lastAutomaticSync = now
        await library.sync()
    }
    func load() async {
        guard hasAccess, !checkingAccess else { return }
        if let loadingTask { await loadingTask.value; return }
        guard !ready else { return }
        // This view model owns the read. SwiftUI may cancel an access-change
        // task while another caller still needs the same pending result.
        let task = Task {
            defer { loadingTask = nil }
            await loadMemberContent()
        }
        loadingTask = task
        await task.value
    }

    private func loadMemberContent() async {
        error = nil
        let started = Date()
        logger.info("Local library load started")
        do {
            // Core content is read only after confirmed access. Mutable progress
            // loads independently; the UI must not present invented zero counts.
            async let catalogue: Void = library.load()
            try await progress.load()
            prepareWelcome()
            try await catalogue
            try Task.checkCancellation()
            guard hasAccess, !checkingAccess else { return }
            if !checkedIntroduction {
                do {
                    try await fantasy.load()
                    guard hasAccess, !checkingAccess else { return }
                    checkedIntroduction = true
                } catch { /* Profile storage must never block library access. */  }
            }
            // Prepare the first visible presentation before mounting Today. This
            // is read-only; its existing appearance task persists the daily selection.
            // A revision can change while the worker is preparing (for example,
            // introduction loading); never reveal a discarded, empty presentation.
            while hasAccess && !checkingAccess {
                try Task.checkCancellation()
                if await today.refresh() {
                    guard hasAccess, !checkingAccess else { return }
                    today.focusNextRead()
                    ready = true
                    showingStoryteller = dailyWelcome == nil && checkedIntroduction && writingUnlocked && !fantasy.introductionSeen
                    logger.info("Local library ready in \(Date().timeIntervalSince(started), privacy: .public) seconds; purchase check pending: \(self.purchases.checking, privacy: .public)")
                    break
                }
            }
        } catch { self.error = error.localizedDescription }
    }
}
