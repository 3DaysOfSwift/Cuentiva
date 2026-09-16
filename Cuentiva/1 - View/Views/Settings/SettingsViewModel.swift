import Foundation
import Observation
@MainActor @Observable final class SettingsViewModel {
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    var error: String?
    var resetConfirmation = false
    var words: [String] { progress.snapshot.vocabulary.keys.sorted() }
    func state(_ word: String) -> VocabularyState { progress.snapshot.vocabulary[word] ?? .unknown }
    init(progress: any ProgressFeature = AppModel.shared.progress, purchases: any PurchaseFeature = AppModel.shared.purchases) { self.progress = progress; self.purchases = purchases }
    func set(_ word: String, state: VocabularyState) async { do { try await progress.setVocabulary(word, state: state) } catch { self.error = error.localizedDescription } }
    func reset() async { do { try await progress.reset() } catch { self.error = error.localizedDescription } }
    func restore() async { do { try await purchases.restore() } catch { self.error = error.localizedDescription } }
}
