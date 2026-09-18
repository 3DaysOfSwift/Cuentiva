import Foundation
import OSLog
import Observation

@MainActor @Observable final class RootViewModel {
    private let progress: any ProgressFeature
    var writingUnlocked: Bool { progress.snapshot.writingUnlocked }
    private let purchases: any PurchaseFeature
    private let library: any LibraryFeature
    private var loading = false
    private var hasEnteredBackground = false
    private var starting = false
    private var lastAutomaticSync: Date?
    private let logger = Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "Launch")
    private let fantasy: any FantasyFeature
    private var checkedIntroduction = false
    var showingStoryteller = false
    var ready = false
    var error: String?
    var hasAccess: Bool { purchases.hasAccess }
    init(
        purchases: any PurchaseFeature = AppModel.shared.purchases,
        library: any LibraryFeature = AppModel.shared.library,
        progress: any ProgressFeature = AppModel.shared.progress, fantasy: any FantasyFeature = AppModel.shared.fantasy
    ) {
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
        async let local: Void = load()
        async let access: Void = refreshPurchases()
        _ = await (local, access)
        await syncLibrary()
    }

    func enteredBackground() { hasEnteredBackground = true }

    func becameActive() async {
        // The first active event belongs to start(), not a second launch check.
        guard hasEnteredBackground else { return }
        hasEnteredBackground = false
        async let access: Void = refreshPurchases()
        async let catalogue: Void = syncLibrary()
        _ = await (access, catalogue)
    }

    var checkingAccess: Bool { purchases.checking }
    func refreshPurchases() async { await purchases.refresh() }
    func syncLibrary() async {
        guard ready, !library.syncing else { return }
        // Initial appearance and scene activation can arrive together. Automatic
        // checks are coalesced; Settings still offers an explicit retry.
        let now = Date()
        guard lastAutomaticSync.map({ now.timeIntervalSince($0) >= 3600 }) ?? true else { return }
        lastAutomaticSync = now
        await library.sync()
    }
    func load() async {
        guard !loading, !ready else { return }
        loading = true
        defer { loading = false }
        error = nil
        let started = Date()
        logger.info("Local library load started")
        do {
            // Library.load owns progress loading. No StoreKit or network request
            // participates in the first local-content render.
            try await library.load()
            ready = true
            logger.info(
                "Local library ready in \(Date().timeIntervalSince(started), privacy: .public) seconds; purchase check pending: \(self.purchases.checking, privacy: .public)"
            )
            if !checkedIntroduction {
                do {
                    try await fantasy.load()
                    showingStoryteller = writingUnlocked && !fantasy.introductionSeen
                    checkedIntroduction = true
                } catch { /* Profile storage must never block library access. Write offers a retry. */  }
            }
        } catch { self.error = error.localizedDescription }
    }
}
