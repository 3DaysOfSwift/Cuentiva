import Foundation
import Observation
@MainActor @Observable final class RootViewModel {
    private let purchases: any PurchaseFeature
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    private var loading = false
    var ready = false
    var error: String?
    var hasAccess: Bool { purchases.hasAccess }
    init(purchases: any PurchaseFeature = AppModel.shared.purchases, library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress) {
        self.purchases = purchases; self.library = library; self.progress = progress
    }
    func load() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        error = nil
        async let purchaseLoad: Void = purchases.refresh()
        do { async let books: Void = library.load(); async let state: Void = progress.load(); _ = try await (books, state); await purchaseLoad; ready = true }
        catch { await purchaseLoad; self.error = error.localizedDescription }
    }
}
