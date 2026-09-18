import Foundation
import Observation
@MainActor @Observable final class PaywallViewModel {
    private let purchases: any PurchaseFeature
    var busy = false
    var error: String?
    var declined = false
    var title: String { "Your next chapter\nis waiting." }
    var selectedPlan: LibraryPlan = .annual
    var button: String { "Subscribe · \(price)" }
    var price: String { price(for: selectedPlan) }
    func price(for plan: LibraryPlan) -> String {
        purchases.offers.first { $0.id == plan.productID }.map { "\($0.displayPrice) / \(plan.billingPeriod)" } ?? "Price unavailable"
    }
    func available(_ plan: LibraryPlan) -> Bool { purchases.offers.contains { $0.id == plan.productID } }
    var available: Bool { available(selectedPlan) }
    var annualSaves: Bool {
        guard let month = purchases.offers.first(where: { $0.id == LibraryPlan.monthly.productID }),
              let year = purchases.offers.first(where: { $0.id == LibraryPlan.annual.productID }) else { return false }
        return year.price < month.price * 12
    }
    var storeMessage: String? { purchases.message }
    init(purchases: any PurchaseFeature = AppModel.shared.purchases) { self.purchases = purchases }
    func purchase() async { guard !busy else { return }; busy = true; defer { busy = false }; error = nil; do { try await purchases.purchase(plan: selectedPlan) } catch { self.error = error.localizedDescription } }
    func restore() async { guard !busy else { return }; busy = true; defer { busy = false }; error = nil; do { try await purchases.restore() } catch { self.error = error.localizedDescription } }
    func reload() async { await purchases.refresh() }
}
