import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct RootViewModelTests {
    @Test func unpaidLaunchReadsOnlyIntroductionAndDoesNotSync() async throws {
        let purchases = TestPurchases()
        let progress = ProgressManager(repository: MemoryProgress())
        let library = GatedLaunchLibrary(gated: false)
        let root = makeRoot(purchases, library, progress)
        await root.start()
        #expect(root.dailyWelcome == nil)
        #expect(root.onboardingReady)
        #expect(root.canShowContent)
        #expect(!progress.loaded) // The welcome does not open or wait for the database.
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
        await root.start()
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
        #expect(root.today.dailyReads.map(\.id) == library.books.map(\.id))
        #expect(root.today.focusedRead?.id == library.books.first?.id)
        #expect(library.dailyPreparations == 0) // Launch prepares display without saving a selection.

        purchases.checking = true
        #expect(!root.canShowContent)
        purchases.checking = false
        await root.accessChanged()
        #expect(root.canShowContent)
        #expect(root.today.dailyReads.map(\.id) == library.books.map(\.id))
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

    private func makeRoot(_ purchases: TestPurchases, _ library: GatedLaunchLibrary,
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
    var loads = 0
    var syncs = 0
    var failure: AppFailure?
    private var gated: Bool
    init(gated: Bool = true) { self.gated = gated }
    func loadIntroduction() async throws {}
    func load() async throws {
        loads += 1
        if let failure { throw failure }
        if gated { await withCheckedContinuation { continuation = $0 } }
    }
    func finish() { gated = false; let pending = continuation; continuation = nil; pending?.resume() }
    func sync() async { syncs += 1 }
    func matchingBooks(_ query: LibraryQuery) async -> [Book] { books }
    func presentation(_ query: LibraryQuery) async -> LibraryPresentation {
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
