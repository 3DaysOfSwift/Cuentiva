import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct RootViewModelTests {
    @Test func launchRendersLocalContentBeforePurchaseRefreshOrSync() async throws {
        let purchases = TestPurchases(); purchases.checking = true
        let progress = ProgressManager(repository: MemoryProgress())
        let repository = LaunchBooks()
        let library = LibraryManager(repository: repository, purchases: purchases, progress: progress)
        let root = RootViewModel(purchases: purchases, library: library, progress: progress,
            fantasy: FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator()))
        await root.load()
        #expect(root.ready)
        #expect(root.checkingAccess)
        #expect(!root.hasAccess)
        #expect(purchases.refreshCalls == 0)
        #expect(await repository.syncCalls == 0)
        await root.refreshPurchases()
        await root.syncLibrary()
        #expect(purchases.refreshCalls == 1)
        #expect(await repository.syncCalls == 1)
        await root.syncLibrary()
        #expect(await repository.syncCalls == 1) // duplicate scene activation is coalesced
    }

    @Test func initialSceneActivationDoesNotRepeatStartupPurchaseCheck() async throws {
        let purchases = TestPurchases()
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: [sample()]), purchases: purchases,
            progress: progress)
        let root = RootViewModel(purchases: purchases, library: library, progress: progress,
            fantasy: FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator()))
        await root.becameActive()
        #expect(purchases.refreshCalls == 0)
        await root.start()
        #expect(root.ready)
        #expect(purchases.refreshCalls == 1)
        await root.becameActive()
        #expect(purchases.refreshCalls == 1)
        root.enteredBackground()
        await root.becameActive()
        #expect(purchases.refreshCalls == 2)
    }

    @Test func onboardingCanAppearWhileFullCatalogueIsStillLoading() async throws {
        let purchases = TestPurchases()
        let library = GatedLaunchLibrary()
        let root = RootViewModel(purchases: purchases, library: library,
            progress: ProgressManager(repository: MemoryProgress()),
            fantasy: FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator()))
        let launch = Task { await root.start() }
        defer { library.finish(); launch.cancel() }
        try await waitUntil { library.continuation != nil }
        #expect(root.onboardingReady)
        #expect(!root.ready)
        #expect(root.canShowContent)
        // A purchase must not expose an unprepared member library.
        purchases.hasAccess = true
        #expect(!root.canShowContent)
        library.finish()
        await launch.value
        #expect(root.ready)
        #expect(root.canShowContent)
    }

    @Test func rootLoadsIsolatedGraph() async throws {
        let (p, s, l, _, _) = try await makeViewModelTestGraph(); let vm = RootViewModel(purchases: p, library: l, progress: s, fantasy: FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator()))
        await vm.load(); #expect(vm.ready); #expect(!vm.hasAccess)
    }
}

@MainActor private final class GatedLaunchLibrary: LibraryFeature {
    let books = [sample()]
    var introduction: Book? { books.first }
    let revision = LibraryRevision()
    var syncing = false
    var syncMessage: String?
    var continuation: CheckedContinuation<Void, Never>?
    func loadIntroduction() async throws {}
    func load() async throws { await withCheckedContinuation { continuation = $0 } }
    func finish() { let pending = continuation; continuation = nil; pending?.resume() }
    func sync() async {}
    func matchingBooks(_ query: LibraryQuery) async -> [Book] { books }
    func presentation(_ query: LibraryQuery) async -> LibraryPresentation { LibraryPresentation(books: books) }
    func prepareDailyReads() async throws {}
    func loadMoreDailyReads() async throws {}
}
