import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct HomeViewModelTests {
    @Test func dailyCarouselFocusesNextUnreadAndAllowsBrowsingCompletedBooks() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: (0..<3).map { sample("carousel-\($0)") }), purchases: purchases, progress: progress)
        try await library.load()
        let home = HomeViewModel(library: library, progress: progress)
        await home.prepareDailyReads()
        let first = try #require(home.focusedRead)
        #expect(home.readButtonTitle == "Read book 1")
        try await progress.recordEncounter(book: first, sentence: first.sentences[0])
        _ = try await progress.complete(book: first)
        await home.refresh()
        home.focusNextRead()
        #expect(home.readButtonTitle == "Read book 2")
        #expect(home.focusedRead?.id != first.id)
        #expect(home.dailyReads.contains { $0.id == first.id })
        home.focusedBookID = first.id
        #expect(home.readButtonTitle == "Read again")
        #expect(home.focusedRead?.id == first.id)
        #expect(home.completed(first))
    }

    @Test func staleLibraryResponseDoesNotReplaceNewSearch() async throws {
        let library = DelayedLibrary()
        let home = HomeViewModel(library: library, progress: ProgressManager(repository: MemoryProgress()))
        home.query = "first"
        let first = Task { await home.refresh() }
        try await waitUntil { library.pending.count == 1 }
        home.query = "second"
        let second = Task { await home.refresh() }
        try await waitUntil { library.pending.count == 2 }
        library.pending[1].resume(returning: .init(books: [sample("second")]))
        await second.value
        library.pending[0].resume(returning: .init(books: [sample("first")]))
        await first.value
        #expect(home.books.map(\.id) == ["second"])
    }
}
