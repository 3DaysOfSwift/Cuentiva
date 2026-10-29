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

@Suite(.timeLimit(.minutes(1))) @MainActor struct SettingsViewModelTests {
    #if DEBUG
    @Test func verbPreviewCanBeEnabledAndDisabledWithoutAddingDays() async throws {
        let (p, s, l, _, _) = try await makeViewModelTestGraph()
        let model = SettingsViewModel(library: l, progress: s, purchases: p)
        #expect(!model.verbTrainingPreview)
        await model.toggleVerbTrainingPreview()
        #expect(model.verbTrainingPreview)
        #expect(s.snapshot.verbTrainingUnlocked)
        #expect(s.snapshot.practiceDays.isEmpty)
        await model.toggleVerbTrainingPreview()
        #expect(!model.verbTrainingPreview)
        #expect(!s.snapshot.verbTrainingUnlocked)
    }
    #endif
    @Test func settingsRestoreExplainsExistingAndRecoveredAccess() async throws {
        let (p,s,l,_,_) = try await makeViewModelTestGraph()
        let vm = SettingsViewModel(library: l, progress: s, purchases: p)
        p.hasAccess = true
        await vm.restore().value
        #expect(vm.restoreMessage?.contains("already have full access") == true)
        #expect(vm.restoreError == nil)
        #expect(!vm.restoring)
        p.hasAccess = false; p.restoresAccess = true
        await vm.restore().value
        #expect(vm.restoreMessage?.contains("Purchase restored") == true)
        #expect(vm.hasAccess)
    }

    @Test func settingsRestoreReplacesStaleFeedbackAndNeverInventsSuccess() async throws {
        let (p,s,l,_,_) = try await makeViewModelTestGraph()
        let vm = SettingsViewModel(library: l, progress: s, purchases: p)
        await vm.restore().value
        #expect(vm.restoreError != nil)
        #expect(vm.restoreMessage == nil)
        p.restoreFailure = .unavailable("Store unavailable")
        await vm.restore().value
        #expect(vm.restoreError == "Store unavailable")
        #expect(!vm.restoring)
        p.restoreFailure = nil; p.hasAccess = true
        await vm.restore().value
        #expect(vm.restoreError == nil)
        #expect(vm.restoreMessage != nil)
    }
    @Test func repeatedRestoreWaitsForTheSameOperationAndFailureAllowsRetry() async throws {
        let (_, progress, library, _, _) = try await makeViewModelTestGraph()
        let purchases = SettingsRestorePurchases()
        let vm = SettingsViewModel(library: library, progress: progress, purchases: purchases)
        let first = vm.restore()
        defer { purchases.release(); first.cancel() }
        let repeated = vm.restore()
        #expect(vm.restoring)
        await purchases.waitForArrival()
        #expect(purchases.restoreCalls == 1)
        purchases.release()
        await first.value
        await repeated.value
        #expect(!vm.restoring)
        #expect(vm.restoreError == "Controlled restore failure")
        #expect(vm.restoreMessage == nil)
        purchases.shouldFail = false
        await vm.restore().value
        #expect(purchases.restoreCalls == 2)
        #expect(vm.hasAccess)
        #expect(vm.restoreError == nil)
        #expect(vm.restoreMessage?.contains("Purchase restored") == true)
    }

    @Test func dispatchedRestoreStillReportsVerifiedAccessAfterCancellation() async throws {
        let (_, progress, library, _, _) = try await makeViewModelTestGraph()
        let purchases = SettingsRestorePurchases()
        purchases.shouldFail = false
        let vm = SettingsViewModel(library: library, progress: progress, purchases: purchases)
        let task = vm.restore()
        defer { purchases.release(); task.cancel() }
        await purchases.waitForArrival()
        task.cancel()
        purchases.release()
        await task.value
        #expect(purchases.restoreCalls == 1)
        #expect(vm.hasAccess)
        #expect(!vm.restoring)
        #expect(vm.restoreError == nil)
        #expect(vm.restoreMessage?.contains("Purchase restored") == true)
    }

    @Test func cancelledRestoreBeforeDispatchDoesNotContactStoreAndCanRetry() async throws {
        let (_, progress, library, _, _) = try await makeViewModelTestGraph()
        let purchases = SettingsRestorePurchases()
        let vm = SettingsViewModel(library: library, progress: progress, purchases: purchases)
        let task = vm.restore()
        task.cancel()
        await task.value
        #expect(purchases.restoreCalls == 0)
        #expect(!vm.restoring)
        #expect(vm.restoreError == nil)
        #expect(vm.restoreMessage == nil)
        purchases.shouldFail = false
        purchases.release()
        await vm.restore().value
        #expect(purchases.restoreCalls == 1)
        #expect(vm.hasAccess)
    }

}


@MainActor private final class SettingsRestorePurchases: PurchaseFeature {
    var hasAccess = false
    var checking = false
    var offers: [Product] { [] }
    var message: String?
    var restoreCalls = 0
    var shouldFail = true
    private var pending: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    private var released = false
    func refresh() async {}
    func purchase(plan: InAppPurchases) async throws {}
    func restore() async throws {
        restoreCalls += 1
        if !released {
            await withCheckedContinuation {
                pending = $0
                arrival?.resume()
                arrival = nil
            }
        }
        if shouldFail { throw AppFailure.unavailable("Controlled restore failure") }
        hasAccess = true
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
