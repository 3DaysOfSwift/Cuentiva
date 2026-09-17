import Foundation
import Observation
@MainActor @Observable final class SettingsViewModel {
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    var error: String?
    var resetConfirmation = false
    private(set) var restoring = false
    private(set) var restoreMessage: String?
    private(set) var restoreError: String?
    var hasAccess: Bool { purchases.hasAccess }
    var words: [String] { progress.snapshot.vocabulary.keys.sorted() }
    func state(_ word: String) -> VocabularyState { progress.snapshot.vocabulary[word] ?? .unknown }
    init(progress: any ProgressFeature = AppModel.shared.progress, purchases: any PurchaseFeature = AppModel.shared.purchases) { self.progress = progress; self.purchases = purchases }
    func set(_ word: String, state: VocabularyState) async { do { try await progress.setVocabulary(word, state: state) } catch { self.error = error.localizedDescription } }
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
                    ? "Your lifetime purchase is active. You already have full access to Cuentiva."
                    : "Purchase restored. Your lifetime access to Cuentiva is ready."
            } else {
                restoreError = "No active purchase was found. Check the Apple Account used for your purchase and try again."
            }
        } catch { restoreError = error.localizedDescription }
    }
}
