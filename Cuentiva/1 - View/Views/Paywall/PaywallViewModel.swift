import Foundation
import Observation
@MainActor @Observable final class PaywallViewModel {
    private let purchases: any PurchaseFeature
    var busy = false
    var error: String?
    var declined = false
    var title: String { "Your next chapter\nis waiting." }
    var button: String { "Unlock Cuentiva" }
    var price: String { purchases.offer.map { "\($0.displayPrice) · One-time purchase" } ?? "Loading price…" }
    var available: Bool { purchases.offer != nil }
    var storeMessage: String? { purchases.message }
    init(purchases: any PurchaseFeature = AppModel.shared.purchases) { self.purchases = purchases }
    func purchase() async { busy = true; defer { busy = false }; error = nil; do { try await purchases.purchase() } catch { self.error = error.localizedDescription } }
    func restore() async { busy = true; defer { busy = false }; do { try await purchases.restore() } catch { self.error = error.localizedDescription } }
    func reload() async { await purchases.refresh() }
}
