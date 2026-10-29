//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation
@MainActor @Observable final class PaywallViewModel {
    private let purchases: any PurchaseFeature
    private(set) var busy = false
    @ObservationIgnored private var operationTask: Task<Void, Never>?
    @ObservationIgnored private var reloadTask: Task<Void, Never>?
    var error: String?
    var title: String { "Your next chapter\nis waiting." }
    var selectedPlan: InAppPurchases = .annual
    var trialNotice: String? {
        guard purchases.hasOneWeekTrial(for: selectedPlan) else { return nil }
        return "1 week free trial · then \(price). Cancel at least 24 hours before the trial ends to avoid payment."
    }
    var button: String { "1 week free trial · \(price)" }
    var price: String { price(for: selectedPlan) }
    func price(for plan: InAppPurchases) -> String {
        purchases.offer(for: plan).map { "\($0.displayPrice) / \(plan.billingPeriod)" } ?? "Price unavailable"
    }
    func available(_ plan: InAppPurchases) -> Bool { purchases.offer(for: plan) != nil }
    var available: Bool { available(selectedPlan) }
    var annualSaves: Bool { purchases.annualPlanSaves }
    var storeMessage: String? { purchases.message }
    init(purchases: any PurchaseFeature = AppModel.shared.purchases) { self.purchases = purchases }
    // Purchase and Restore share one admission gate. Once dispatched, the operation
    // finishes even if this screen disappears, so verified access can be delivered.
    @discardableResult
    func purchase() -> Task<Void, Never> {
        if let operationTask { return operationTask }
        let plan = selectedPlan
        busy = true
        error = nil
        let task = Task {
            defer { busy = false; operationTask = nil }
            do {
                try Task.checkCancellation()
                try await purchases.purchase(plan: plan)
            } catch is CancellationError {
                // Cancellation before dispatch is not a purchase failure.
            } catch {
                self.error = error.localizedDescription
            }
        }
        operationTask = task
        return task
    }

    @discardableResult
    func restore() -> Task<Void, Never> {
        if let operationTask { return operationTask }
        busy = true
        error = nil
        let task = Task {
            defer { busy = false; operationTask = nil }
            do {
                try Task.checkCancellation()
                try await purchases.restore()
            } catch is CancellationError {
                // A cancelled restore does not need an error message.
            } catch {
                self.error = error.localizedDescription
            }
        }
        operationTask = task
        return task
    }

    @discardableResult
    func reload() -> Task<Void, Never> {
        if let reloadTask { return reloadTask }
        let task = Task {
            defer { reloadTask = nil }
            guard !Task.isCancelled else { return }
            await purchases.refresh()
        }
        reloadTask = task
        return task
    }
}
