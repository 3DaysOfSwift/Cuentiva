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
    @Test func repeatedResetSharesFailureAndRetryPreservesProgressUntilSaved() async throws {
        let (purchases, _, library, _, _) = try await makeViewModelTestGraph()
        var saved = LearnerProgress()
        saved.completed = ["read-book"]
        let repository = SettingsResetRepository(value: saved)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let model = SettingsViewModel(library: library, progress: progress, purchases: purchases)
        let first = model.reset()
        let repeated = model.reset()
        await repository.waitForSave()
        #expect(progress.snapshot.completed == saved.completed)
        #expect(await repository.saveCalls == 1)
        await repository.release(failing: true)
        await first.value
        await repeated.value
        #expect(model.error == "Controlled reset failure")
        #expect(progress.snapshot.completed == saved.completed)
        #expect(await repository.value.completed == saved.completed)
        await repository.release(failing: false)
        await model.reset().value
        #expect(model.error == nil)
        #expect(progress.snapshot.completed.isEmpty)
        #expect(await repository.value.completed.isEmpty)
        #expect(await repository.saveCalls == 2)
    }

    @Test func cancelledResetBeforeDispatchPreservesProgressWithoutWriting() async throws {
        let (purchases, _, library, _, _) = try await makeViewModelTestGraph()
        var saved = LearnerProgress()
        saved.completed = ["read-book"]
        let repository = SettingsResetRepository(value: saved)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let model = SettingsViewModel(library: library, progress: progress, purchases: purchases)
        let task = model.reset()
        task.cancel()
        await task.value
        #expect(await repository.saveCalls == 0)
        #expect(progress.snapshot.completed == saved.completed)
        #expect(model.error == nil)
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


private actor SettingsResetRepository: ProgressRepository {
    var value: LearnerProgress
    private(set) var saveCalls = 0
    private var pending: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    private var released = false
    private var failing = false
    init(value: LearnerProgress) { self.value = value }
    func load() -> LearnerProgress { value }
    func save(_ next: LearnerProgress) async throws {
        saveCalls += 1
        if !released {
            await withCheckedContinuation {
                pending = $0
                arrival?.resume()
                arrival = nil
            }
        }
        if failing { throw AppFailure.unavailable("Controlled reset failure") }
        value = next
    }
    func waitForSave() async {
        if pending != nil { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func release(failing: Bool) {
        self.failing = failing
        released = true
        pending?.resume()
        pending = nil
    }
}
