import Foundation
import Observation
@MainActor @Observable final class RootViewModel {
    private let purchases: any PurchaseFeature
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    private var loading = false
    private let fantasy: any FantasyFeature
    private var checkedIntroduction = false
    var showingStoryteller = false
    var ready = false
    var error: String?
    var hasAccess: Bool { purchases.hasAccess }
    init(purchases: any PurchaseFeature = AppModel.shared.purchases, library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress, fantasy: any FantasyFeature = AppModel.shared.fantasy) {
        self.fantasy = fantasy; self.purchases = purchases; self.library = library; self.progress = progress
    }
    var checkingAccess: Bool { purchases.checking }
    func refreshPurchases() async { await purchases.refresh() }
    func syncLibrary() async {
        guard ready else { return }
        await library.sync()
    }
    func load() async {
        guard !loading, !ready else { return }
        loading = true; defer { loading = false }
        error = nil
        do {
            // Library.load owns progress loading. No StoreKit or network request
            // participates in the first local-content render.
            try await library.load()
            ready = true
            if !checkedIntroduction {
                do {
                    try await fantasy.load()
                    showingStoryteller = !fantasy.introductionSeen
                    checkedIntroduction = true
                } catch { /* Profile storage must never block library access. Write offers a retry. */ }
            }
        } catch { self.error = error.localizedDescription }
    }
}
