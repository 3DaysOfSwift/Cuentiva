import Foundation
import Observation
@MainActor @Observable final class PaywallViewModel {
    private let purchases: any PurchaseFeature
    var busy = false
    var error: String?
    var title: String { "Your next chapter\nis waiting." }
    var selectedPlan: LibraryPlan = .annual
    var trialNotice: String? {
        guard purchases.hasOneWeekTrial(for: selectedPlan) else { return nil }
        return "1 week free trial · then \(price). Cancel at least 24 hours before the trial ends to avoid payment."
    }
    var button: String { "1 week free trial · \(price)" }
    var price: String { price(for: selectedPlan) }
    func price(for plan: LibraryPlan) -> String {
        purchases.offer(for: plan).map { "\($0.displayPrice) / \(plan.billingPeriod)" } ?? "Price unavailable"
    }
    func available(_ plan: LibraryPlan) -> Bool { purchases.offer(for: plan) != nil }
    var available: Bool { available(selectedPlan) }
    var annualSaves: Bool { purchases.annualPlanSaves }
    var storeMessage: String? { purchases.message }
    init(purchases: any PurchaseFeature = AppModel.shared.purchases) { self.purchases = purchases }
    func purchase() async {
        guard !busy else { return }
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await purchases.purchase(plan: selectedPlan)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await purchases.restore()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reload() async { await purchases.refresh() }
}
