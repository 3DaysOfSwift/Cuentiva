import Foundation
import Observation
@MainActor @Observable final class OnboardingViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    var lesson: Book?
    var error: String?
    var book: Book? { library.introduction }
    var completed: Bool { progress.snapshot.completed.contains("cafe") }
    init(library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress, purchases: any PurchaseFeature = AppModel.shared.purchases) { self.library = library; self.progress = progress; self.purchases = purchases }
    func restore() async { do { try await purchases.restore() } catch { self.error = error.localizedDescription } }
}
