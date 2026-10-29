//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
import StoreKit
@testable import Cuentiva

@Suite(.timeLimit(.minutes(1))) @MainActor struct PaywallViewModelTests {
    @Test func selectingPlanDoesNotGrantAccessOrPromiseUnconfirmedTrial() async throws {
        let (p, _, _, _, _) = try await makeViewModelTestGraph()
        let vm = PaywallViewModel(purchases: p)
        #expect(vm.selectedPlan == .annual)
        #expect(vm.trialNotice == nil)
        vm.selectedPlan = .monthly
        #expect(!p.hasAccess)
        #expect(!vm.available)
        #expect(vm.trialNotice == nil)
        await vm.purchase().value
        #expect(p.hasAccess)
    }
    @Test func purchaseCapturesPlanAndRepeatedActionsAwaitThePendingOperation() async {
        let purchases = GatedPaywallPurchases()
        let vm = PaywallViewModel(purchases: purchases)
        vm.selectedPlan = .monthly
        let first = vm.purchase()
        defer { purchases.gate.release(); first.cancel() }
        #expect(vm.busy)
        vm.selectedPlan = .annual
        let repeated = vm.purchase()
        let restore = vm.restore()
        await purchases.gate.waitForArrival()
        #expect(purchases.plans == [.monthly])
        #expect(purchases.restoreCalls == 0)
        purchases.gate.release()
        await first.value
        await repeated.value
        await restore.value
        #expect(!vm.busy)
        #expect(vm.error != nil)
        await vm.restore().value
        #expect(purchases.restoreCalls == 1)
        #expect(vm.error == nil)
    }

    @Test func pendingRestoreSharesCompletionAndRejectsPurchase() async {
        let purchases = GatedPaywallPurchases()
        let vm = PaywallViewModel(purchases: purchases)
        let first = vm.restore()
        defer { purchases.gate.release(); first.cancel() }
        #expect(vm.busy)
        let repeated = vm.restore()
        let purchase = vm.purchase()
        await purchases.gate.waitForArrival()
        #expect(purchases.restoreCalls == 1)
        #expect(purchases.plans.isEmpty)
        purchases.gate.release()
        await first.value
        await repeated.value
        await purchase.value
        #expect(!vm.busy)
        #expect(vm.error == nil)
    }

    @Test func cancellationBeforeDispatchDoesNotStartPurchaseOrShowFailure() async {
        let purchases = GatedPaywallPurchases()
        let vm = PaywallViewModel(purchases: purchases)
        let task = vm.purchase()
        task.cancel()
        await task.value
        #expect(purchases.plans.isEmpty)
        #expect(!vm.busy)
        #expect(vm.error == nil)
    }

    @Test func repeatedReloadSharesPendingRefreshAndAllowsAnotherAfterCompletion() async {
        let purchases = GatedPaywallPurchases()
        let vm = PaywallViewModel(purchases: purchases)
        let first = vm.reload()
        defer { purchases.gate.release(); first.cancel() }
        let repeated = vm.reload()
        await purchases.gate.waitForArrival()
        #expect(purchases.refreshCalls == 1)
        purchases.gate.release()
        await first.value
        await repeated.value
        await vm.reload().value
        #expect(purchases.refreshCalls == 2)
    }

}


@MainActor private final class GatedPaywallPurchases: PurchaseFeature {
    let gate = PaywallOperationGate()
    var hasAccess = false
    var checking = false
    var offers: [Product] { [] }
    var message: String?
    var plans: [InAppPurchases] = []
    var restoreCalls = 0
    var refreshCalls = 0
    func purchase(plan: InAppPurchases) async throws {
        plans.append(plan)
        await gate.wait()
        throw AppFailure.unavailable("Controlled purchase failure")
    }
    func restore() async throws {
        restoreCalls += 1
        await gate.wait()
    }
    func refresh() async {
        refreshCalls += 1
        await gate.wait()
    }
}

@MainActor private final class PaywallOperationGate {
    private var pending: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    private var released = false
    func wait() async {
        guard !released else { return }
        await withCheckedContinuation {
            pending = $0
            arrival?.resume()
            arrival = nil
        }
    }
    func waitForArrival() async {
        if pending != nil { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func release() {
        released = true
        pending?.resume()
        pending = nil
    }
}
