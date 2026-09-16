import Foundation
import Observation
@MainActor @Observable final class PaywallViewModel {
    private let purchases: any PurchaseFeature
    var busy = false
    var error: String?
    var declined = false
    var title: String { purchases.trialEligible ? "Your next chapter\nstarts free." : "Your next chapter\nis waiting." }
    var button: String { purchases.trialEligible ? "Start 7-day free trial" : "Subscribe to Cuentiva" }
    var price: String { purchases.offer.map { "\($0.displayPrice) per month" } ?? "Loading subscription…" }
    var trial: Bool { purchases.trialEligible }
    var available: Bool { purchases.offer != nil }
    var storeMessage: String? { purchases.message }
    init(purchases: any PurchaseFeature = AppModel.shared.purchases) { self.purchases = purchases }
    func purchase() async { busy = true; defer { busy = false }; error = nil; do { try await purchases.purchase() } catch { self.error = error.localizedDescription } }
    func restore() async { busy = true; defer { busy = false }; do { try await purchases.restore() } catch { self.error = error.localizedDescription } }
    func reload() async { await purchases.refresh() }
}
