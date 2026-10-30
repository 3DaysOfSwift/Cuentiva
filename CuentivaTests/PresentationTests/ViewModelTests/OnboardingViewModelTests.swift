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

@Suite @MainActor struct OnboardingViewModelTests {
    @Test func successfulRestoreRetryClearsPreviousFailure() async throws {
        let (_, progress, library, _, _) = try await makeViewModelTestGraph()
        let purchases = RetryOnboardingPurchases()
        let model = OnboardingViewModel(library: library, progress: progress, purchases: purchases)
        await model.restore().value
        #expect(model.error != nil)
        purchases.fail = false
        await model.restore().value
        #expect(model.error == nil)
        #expect(purchases.restoreCalls == 2)
    }

    @Test func cancellationBeforeRestoreDispatchAllowsRetry() async throws {
        let (_, progress, library, _, _) = try await makeViewModelTestGraph()
        let purchases = RetryOnboardingPurchases()
        purchases.fail = false
        let model = OnboardingViewModel(library: library, progress: progress, purchases: purchases)
        let cancelled = model.restore()
        cancelled.cancel()
        await cancelled.value
        #expect(purchases.restoreCalls == 0)
        #expect(model.error == nil)
        await model.restore().value
        #expect(purchases.restoreCalls == 1)
    }

    @Test(.timeLimit(.minutes(1))) func repeatedRestoreSharesPendingWork() async throws {
        let (_, progress, library, _, _) = try await makeViewModelTestGraph()
        let purchases = RetryOnboardingPurchases()
        purchases.fail = false
        purchases.hold = true
        let model = OnboardingViewModel(library: library, progress: progress, purchases: purchases)
        let first = model.restore()
        await purchases.waitForRestore()
        let second = model.restore()
        #expect(first == second)
        #expect(purchases.restoreCalls == 1)
        purchases.release()
        await first.value
        await second.value
        await model.restore().value
        #expect(purchases.restoreCalls == 2)
    }

    @Test func onboardingKeepsItsBook() async throws {
        let (p,s,l,_,_) = try await makeViewModelTestGraph(); let vm = OnboardingViewModel(library: l, progress: s, purchases: p)
        #expect(vm.book?.id == "cafe"); #expect(!vm.completed)
    }
    @Test func progressFailureBlocksReadingAndRetryRestoresSavedCompletion() async throws {
        let (p, _, library, _, _) = try await makeViewModelTestGraph()
        let repository = OnboardingProgressRepository()
        let progress = ProgressManager(repository: repository)
        let model = OnboardingViewModel(library: library, progress: progress, purchases: p)
        #expect(model.book != nil)
        #expect(!model.canStartReading)
        model.startReading()
        #expect(model.lesson == nil)
        await model.prepareProgress()
        #expect(model.preparationError != nil)
        #expect(!model.progressReady)
        await repository.allowLoad(completed: true)
        await model.prepareProgress()
        #expect(model.preparationError == nil)
        #expect(model.completed)
        model.startReading()
        #expect(model.lesson == nil)
    }

    @Test func readyProgressAllowsStartingTheFreeStory() async throws {
        let (p, _, library, _, _) = try await makeViewModelTestGraph()
        let progress = ProgressManager(repository: MemoryProgress())
        let model = OnboardingViewModel(library: library, progress: progress, purchases: p)
        model.startReading()
        #expect(model.lesson == nil)
        await model.prepareProgress()
        #expect(model.canStartReading)
        model.startReading()
        #expect(model.lesson?.id == "cafe")
    }

}


private actor OnboardingProgressRepository: ProgressRepository {
    private var fails = true
    private var value = LearnerProgress()
    func load() throws -> LearnerProgress {
        if fails { throw AppFailure.unavailable("Storage temporarily unavailable") }
        return value
    }
    func save(_ value: LearnerProgress) { self.value = value }
    func allowLoad(completed: Bool) {
        fails = false
        if completed { value.completed.insert("cafe") }
    }
}

@MainActor private final class RetryOnboardingPurchases: PurchaseFeature {
    var hasAccess = false
    var checking = false
    var offers: [Product] { [] }
    var message: String?
    var fail = true
    private(set) var restoreCalls = 0
    var hold = false
    private var pending: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    func waitForRestore() async {
        if pending != nil { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func release() {
        hold = false
        pending?.resume()
        pending = nil
    }
    func refresh() async {}
    func purchase(plan: InAppPurchases) async throws {}
    func restore() async throws {
        restoreCalls += 1
        if hold {
            await withCheckedContinuation {
                pending = $0
                arrival?.resume()
                arrival = nil
            }
        }
        if fail { throw AppFailure.unavailable("Controlled restore failure") }
    }
}
