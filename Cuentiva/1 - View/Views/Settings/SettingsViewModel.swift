import Foundation
import Observation
@MainActor @Observable final class SettingsViewModel {
    private let library: any LibraryFeature
    var syncing: Bool { library.syncing }
    var syncMessage: String? { library.syncMessage }
    func syncLibrary() async { await library.sync() }
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    var showingThemePack: ThemePack?
    var themePacks: [ThemePack] {
        ThemePack.allCases.filter { progress.snapshot.earnedThemePacks.contains($0) || progress.snapshot.hasInstalled($0) }
    }
    func hasInstalled(_ pack: ThemePack) -> Bool { progress.snapshot.hasInstalled(pack) }
    var reviewURL: URL? { ReadingMilestones.reviewURL }
    var error: String?
    var resetConfirmation = false
    private(set) var restoring = false
    private(set) var restoreMessage: String?
    private(set) var restoreError: String?
    var isVIP: Bool { progress.snapshot.isVIP }
    var hasAccess: Bool { purchases.hasAccess }
    init(library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress, purchases: any PurchaseFeature = AppModel.shared.purchases) { self.library = library; self.progress = progress; self.purchases = purchases }
    func reset() async { do { try await progress.reset() } catch { self.error = error.localizedDescription } }
    func restore() async {
        guard !restoring else { return }
        restoring = true
        restoreMessage = nil; restoreError = nil
        defer { restoring = false }
        let alreadyOwned = purchases.hasAccess
        do {
            try await purchases.restore()
            if purchases.hasAccess {
                restoreMessage = alreadyOwned
                    ? "Your library access is active. You already have full access to Cuentiva."
                    : "Purchase restored. Your access to Cuentiva is ready."
            } else {
                restoreError = "No active purchase was found. Check the Apple Account used for your purchase and try again."
            }
        } catch { restoreError = error.localizedDescription }
    }
}
