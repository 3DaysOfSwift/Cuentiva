//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite(.timeLimit(.minutes(1))) @MainActor struct RootViewModelTests {
    @Test(arguments: [false, true])
    func languageTipWaitsForSaveAndSharesRepeatedRequests(fails: Bool) async throws {
        let repository = HeldRootProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let day = try #require(progress.dailyWelcome?.day)
        try await progress.acknowledgeWelcome(day: day)
        let purchases = TestPurchases()
        purchases.hasAccess = true
        let root = makeRoot(purchases, GatedLaunchLibrary(gated: false), progress)
        let tip = try #require(root.languageTip?.id)
        await repository.holdNextSave(fails: fails)
        let first = try #require(root.continueLanguageTip())
        let repeated = try #require(root.continueLanguageTip())
        #expect(first == repeated)
        await repository.waitForSave()
        #expect(root.languageTip?.id == tip)
        #expect(root.savingTip)
        first.cancel() // An admitted write is allowed to finish.
        await repository.release()
        await first.value
        #expect(!root.savingTip)
        if fails {
            #expect(root.languageTip?.id == tip)
            #expect(root.tipError != nil)
            await root.continueLanguageTip()?.value
        }
        #expect(root.languageTip == nil)
        #expect(root.tipError == nil)
        #expect(await repository.value.languageTips?.pending == nil)
    }

    @Test func languageTipCancelledBeforeDispatchDoesNotSave() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        try await progress.acknowledgeWelcome(day: try #require(progress.dailyWelcome?.day))
        let purchases = TestPurchases()
        purchases.hasAccess = true
        let root = makeRoot(purchases, GatedLaunchLibrary(gated: false), progress)
        let saves = await repository.saveAttempts
        let task = try #require(root.continueLanguageTip())
        task.cancel()
        await task.value
        #expect(await repository.saveAttempts == saves)
        #expect(root.languageTip != nil)
        #expect(root.tipError == nil)
        await root.continueLanguageTip()?.value
        #expect(root.languageTip == nil)
    }

    @Test(arguments: [false, true])
    func beginDaySharesPreparationAndCancelledResultDoesNotDismiss(cancel: Bool) async throws {
        let purchases = TestPurchases()
        purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = GatedLaunchLibrary(gated: false)
        let root = makeRoot(purchases, library, progress)
        await root.load()
        let welcome = try #require(root.dailyWelcome)
        // The welcome feature saves acknowledgement before forwarding this intent.
        try await progress.acknowledgeWelcome(day: welcome.day)
        library.gatePresentation = true
        let before = library.presentations
        let first = try #require(root.beginDay())
        defer { library.finishPresentation() }
        let repeated = try #require(root.beginDay())
        #expect(first == repeated)
        try await waitUntil { library.pendingPresentation != nil }
        #expect(library.presentations == before + 1)
        #expect(root.dailyWelcome == welcome)
        if cancel { first.cancel() }
        library.finishPresentation()
        await first.value
        if cancel {
            #expect(root.dailyWelcome == welcome)
            await root.beginDay()?.value
        }
        #expect(root.dailyWelcome == nil)
        #expect(root.todayPresentation.dailyReads.map(\.id) == library.books.map(\.id))
    }

    @Test func repeatedLaunchSharesPendingCompletion() async throws {
        let purchases = TestPurchases()
        purchases.hasAccess = true
        let library = GatedLaunchLibrary()
        let root = makeRoot(purchases, library, ProgressManager(repository: MemoryProgress()))
        let first = root.start()
        defer { library.finish() }
        try await waitUntil { library.continuation != nil }
        let repeated = root.start()
        #expect(first == repeated)
        #expect(library.loads == 1)
        #expect(purchases.refreshCalls == 1)
        #expect(!root.ready)
        library.finish()
        await first.value
        await repeated.value
        #expect(root.ready)
        #expect(library.syncs == 1)
    }

    @Test func cancelledLaunchBeforeDispatchCanRetry() async {
        let purchases = TestPurchases()
        let library = GatedLaunchLibrary(gated: false)
        let progress = ProgressManager(repository: MemoryProgress())
        let root = makeRoot(purchases, library, progress)
        let cancelled = root.start()
        cancelled.cancel()
        await cancelled.value
        #expect(purchases.refreshCalls == 0)
        #expect(!progress.loaded)
        #expect(!root.onboardingReady)
        #expect(root.error == nil)
        await root.start().value
        #expect(purchases.refreshCalls == 1)
        #expect(progress.loaded)
        #expect(root.onboardingReady)
    }

    @Test func unpaidLaunchRetryClearsIntroductionFailure() async {
        let purchases = TestPurchases()
        let library = GatedLaunchLibrary(gated: false)
        library.introductionFailure = .invalidBook
        let root = makeRoot(purchases, library, ProgressManager(repository: MemoryProgress()))
        await root.start().value
        #expect(root.error != nil)
        #expect(!root.canShowContent)
        library.introductionFailure = nil
        await root.start().value
        #expect(root.error == nil)
        #expect(root.onboardingReady)
        #expect(root.canShowContent)
        #expect(library.loads == 0)
    }

    @Test func languageTipIsPaidOnlyAndContinueRetriesFailedSave() async throws {
        let repo = MemoryProgress()
        let progress = ProgressManager(repository: repo); try await progress.load()
        let day = try #require(progress.dailyWelcome?.day)
        try await progress.acknowledgeWelcome(day: day)
        let purchases = TestPurchases(); purchases.hasAccess = false
        let root = makeRoot(purchases, GatedLaunchLibrary(gated: false), progress)
        #expect(root.languageTip == nil)
        purchases.hasAccess = true
        #expect(root.languageTip?.id == "noun")
        await repo.setFailure(true)
        await root.continueLanguageTip()?.value
        #expect(root.tipError != nil && root.languageTip?.id == "noun")
        await repo.setFailure(false)
        await root.continueLanguageTip()?.value
        #expect(root.tipError == nil && root.languageTip == nil)
    }

    @Test func automaticSyncSurvivesRelaunchAndChecksAgainNextDay() async throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryProgress()
        let progress = ProgressManager(repository: repo, now: { now })
        try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let library = GatedLaunchLibrary(gated: false)
        let root = makeRoot(purchases, library, progress); root.ready = true
        await root.syncLibrary()
        await root.syncLibrary()
        #expect(library.syncs == 1)
        let restored = ProgressManager(repository: repo, now: { now })
        try await restored.load()
        let relaunched = makeRoot(purchases, library, restored); relaunched.ready = true
        await relaunched.syncLibrary()
        #expect(library.syncs == 1)
        now = now.addingTimeInterval(86400)
        await relaunched.syncLibrary()
        #expect(library.syncs == 2)
        // Settings calls the feature directly, bypassing automatic scheduling.
        await library.sync()
        #expect(library.syncs == 3)
    }

    @Test func storageStartsWhileEntitlementCheckIsStillPending() async throws {
        var entitlementWait: CheckedContinuation<Void, Never>?
        let purchases = PurchaseManager(readEntitlements: {
            await withCheckedContinuation { entitlementWait = $0 }
            return []
        }, readLatest: { _ in nil }, loadProducts: { _ in [] }, observesTransactions: false)
        let progress = ProgressManager(repository: MemoryProgress())
        let library = GatedLaunchLibrary(gated: false)
        let root = makeRoot(purchases, library, progress)
        let launch = Task { await root.start().value }
        defer { entitlementWait?.resume(); entitlementWait = nil; launch.cancel() }
        try await waitUntil { entitlementWait != nil && progress.loaded && root.onboardingReady }
        #expect(purchases.checking)
        #expect(!root.ready)
        #expect(library.loads == 0)
        // SwiftUI may cancel its waiting task; Root still owns shared launch work.
        launch.cancel()
        entitlementWait?.resume(); entitlementWait = nil
        await launch.value
        #expect(root.canShowContent)
        #expect(!root.hasAccess)
    }

    @Test func unpaidLaunchReadsOnlyIntroductionAndDoesNotSync() async throws {
        let purchases = TestPurchases()
        let progress = ProgressManager(repository: MemoryProgress())
        let library = GatedLaunchLibrary(gated: false)
        let root = makeRoot(purchases, library, progress)
        await root.start().value
        #expect(root.dailyWelcome == nil)
        #expect(root.onboardingReady)
        #expect(root.canShowContent)
        #expect(progress.loaded) // Storage prepares even when access is not purchased.
        #expect(!root.ready)
        #expect(library.loads == 0)
        #expect(library.syncs == 0)
        #expect(purchases.refreshCalls == 1)
        await root.becameActive()
        #expect(purchases.refreshCalls == 1)
        root.enteredBackground()
        await root.becameActive()
        #expect(purchases.refreshCalls == 2)
        #expect(library.loads == 0)
    }

    @Test func purchaseLoadsLibraryAndCoalescesRepeatedActivation() async throws {
        let purchases = TestPurchases()
        let progress = ProgressManager(repository: MemoryProgress())
        let library = GatedLaunchLibrary()
        let root = makeRoot(purchases, library, progress)
        await root.start().value
        purchases.hasAccess = true
        #expect(!root.canShowContent)
        let activation = Task { await root.accessChanged() }
        defer { library.finish(); activation.cancel() }
        try await waitUntil { library.continuation != nil }
        let secondActivation = Task { await root.accessChanged() }
        activation.cancel() // SwiftUI can cancel the first task as access changes.
        #expect(library.loads == 1)
        #expect(!root.ready)
        library.finish()
        await activation.value
        await secondActivation.value
        #expect(root.ready)
        #expect(root.canShowContent)
        #expect(library.syncs == 1)
        await root.accessChanged()
        #expect(library.syncs == 1)
        purchases.hasAccess = false
        await root.accessChanged()
        #expect(!root.ready)
        #expect(root.canShowContent) // Returns to the separately loaded introduction.
    }

    @Test func checkingAccessNeverStartsFullLibraryAndFailureCanRetry() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true; purchases.checking = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = GatedLaunchLibrary(gated: false)
        let root = makeRoot(purchases, library, progress)
        await root.load()
        #expect(library.loads == 0)
        purchases.checking = false
        library.failure = .invalidBook
        await root.load()
        #expect(!root.ready)
        #expect(root.error != nil)
        library.failure = nil
        await root.load()
        #expect(root.ready)
        #expect(root.error == nil)
        #expect(progress.loaded)
    }

    @Test func memberScreenWaitsForPreparedTodayAndRetainsItAcrossRechecks() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = GatedLaunchLibrary(gated: false)
        library.gatePresentation = true
        let root = makeRoot(purchases, library, progress)
        let launch = Task { await root.load() }
        defer { library.finishPresentation(); launch.cancel() }
        try await waitUntil { library.pendingPresentation != nil }
        #expect(!root.ready)
        #expect(!root.canShowContent)
        library.finishPresentation()
        await launch.value
        #expect(root.canShowContent)
        #expect(root.dailyWelcome != nil)
        #expect(root.todayPresentation.dailyReads.map(\.id) == library.books.map(\.id))
        #expect(library.dailyPreparations == 0) // Launch prepares display without saving a selection.

        purchases.checking = true
        #expect(!root.canShowContent)
        purchases.checking = false
        await root.accessChanged()
        #expect(root.canShowContent)
        #expect(root.todayPresentation.dailyReads.map(\.id) == library.books.map(\.id))
        #expect(library.loads == 1)
    }

    @Test func accessRevokedDuringPresentationDoesNotRevealMemberScreen() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let library = GatedLaunchLibrary(gated: false)
        library.gatePresentation = true
        let root = makeRoot(purchases, library, ProgressManager(repository: MemoryProgress()))
        let launch = Task { await root.load() }
        defer { library.finishPresentation(); launch.cancel() }
        try await waitUntil { library.pendingPresentation != nil }
        purchases.hasAccess = false
        library.finishPresentation()
        await launch.value
        #expect(!root.ready)
        #expect(!root.canShowContent)
    }

    private func makeRoot(_ purchases: any PurchaseFeature, _ library: GatedLaunchLibrary,
                          _ progress: ProgressManager) -> RootViewModel {
        RootViewModel(purchases: purchases, library: library, progress: progress,
            fantasy: FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator()))
    }
}

@MainActor private final class GatedLaunchLibrary: LibraryFeature {
    let books = [sample()]
    var introduction: Book? { books.first }
    let revision = LibraryRevision()
    var syncing = false
    var syncMessage: String?
    var continuation: CheckedContinuation<Void, Never>?
    var gatePresentation = false
    var pendingPresentation: CheckedContinuation<LibraryPresentation, Never>?
    var dailyPreparations = 0
    var presentations = 0
    var loads = 0
    var syncs = 0
    var failure: AppFailure?
    private var gated: Bool
    init(gated: Bool = true) { self.gated = gated }
    var introductionFailure: AppFailure?
    func loadIntroduction() async throws {
        if let introductionFailure { throw introductionFailure }
    }
    func load() async throws {
        loads += 1
        if let failure { throw failure }
        if gated { await withCheckedContinuation { continuation = $0 } }
    }
    func finish() { gated = false; let pending = continuation; continuation = nil; pending?.resume() }
    func sync() async { syncs += 1 }
    func matchingBooks(_ query: LibraryQuery) async -> [Book] { books }
    func presentation(_ query: LibraryQuery) async -> LibraryPresentation {
        presentations += 1
        if gatePresentation {
            return await withCheckedContinuation { pendingPresentation = $0 }
        }
        return preparedPresentation
    }
    private var preparedPresentation: LibraryPresentation {
        LibraryPresentation(books: books, dailyReads: books, nextRead: books.first)
    }
    func finishPresentation() {
        gatePresentation = false
        let pending = pendingPresentation
        pendingPresentation = nil
        pending?.resume(returning: preparedPresentation)
    }
    func prepareDailyReads() async throws { dailyPreparations += 1 }
    func loadMoreDailyReads() async throws {}
}


private actor HeldRootProgress: ProgressRepository {
    private(set) var value = LearnerProgress()
    private var hold = false
    private var fails = false
    private var pending: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    func load() -> LearnerProgress { value }
    func holdNextSave(fails: Bool) { hold = true; self.fails = fails }
    func save(_ next: LearnerProgress) async throws {
        if hold {
            hold = false
            await withCheckedContinuation { continuation in
                pending = continuation
                arrival?.resume()
                arrival = nil
            }
            if fails { throw AppFailure.unavailable("Controlled save failure") }
        }
        value = next
    }
    func waitForSave() async {
        if pending != nil { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func release() { pending?.resume(); pending = nil }
}
