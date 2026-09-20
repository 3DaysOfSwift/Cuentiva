import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct HomeViewModelTests {
    @Test func dailyCarouselFocusesNextUnreadAndAllowsBrowsingCompletedBooks() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: (0..<3).map { sample("carousel-\($0)") }), purchases: purchases, progress: progress)
        try await progress.load()
        try await library.load()
        let home = HomeViewModel(library: library, progress: progress)
        await home.prepareDailyReads()
        let first = try #require(home.focusedRead)
        #expect(home.readButtonTitle == "Read book")
        try await progress.recordEncounter(book: first, sentence: first.sentences[0])
        _ = try await progress.complete(book: first)
        await home.refresh()
        home.focusNextRead()
        #expect(home.readButtonTitle == "Read book")
        #expect(home.focusedRead?.id != first.id)
        #expect(home.dailyReads.contains { $0.id == first.id })
        home.focusedBookID = first.id
        #expect(home.readButtonTitle == "Read book")
        #expect(home.focusedRead?.id == first.id)
        #expect(home.completed(first))
    }

    @Test func launchRefreshPublishesAnExplicitNextUnreadScrollTarget() async throws {
        let library = DelayedLibrary()
        let home = HomeViewModel(library: library, progress: ProgressManager(repository: MemoryProgress()))
        let first = sample("completed")
        let next = sample("next")
        let refresh = Task { await home.refresh() }
        try await waitUntil { library.pending.count == 1 }
        library.pending[0].resume(returning: .init(dailyReads: [first, next], nextRead: next))
        #expect(await refresh.value)
        #expect(home.focusedBookID == next.id)
        #expect(home.focusedRead?.id == next.id)
    }

    @Test func tappingAnotherBookSelectsItBeforeOpeningTheLesson() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: (0..<3).map { sample("tap-\($0)") }), purchases: purchases, progress: progress)
        try await progress.load()
        try await library.load()
        let home = HomeViewModel(library: library, progress: progress)
        await home.prepareDailyReads()
        let third = try #require(home.dailyReads.last)
        home.tapDailyRead(third)
        #expect(home.focusedBookID == third.id)
        #expect(home.focusedRead?.id == third.id)
        #expect(home.selectedBook == nil)
        home.tapDailyRead(third)
        #expect(home.selectedBook?.id == third.id)
        home.selectedBook = nil
        home.tapDailyRead(sample("outside-daily-selection"))
        #expect(home.focusedBookID == third.id)
        #expect(home.selectedBook == nil)
    }

    @Test func celebratesOnlyNewDailyCompletionWithAnotherUnreadBook() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: (0..<3).map { sample("bounce-\($0)") }), purchases: purchases, progress: progress)
        try await progress.load()
        try await library.load()
        let home = HomeViewModel(library: library, progress: progress)
        await home.prepareDailyReads()
        let first = try #require(home.focusedRead)
        home.selectedBook = first
        home.selectedBook = nil
        await home.readingDismissed()
        #expect(home.readCelebration == 0) // Closing an unfinished lesson is not a completion.
        home.selectedBook = first
        try await progress.recordEncounter(book: first, sentence: first.sentences[0])
        _ = try await progress.completeReading(book: first)
        home.selectedBook = nil
        await home.readingDismissed()
        #expect(home.total == 1)
        #expect(home.focusedRead?.id != first.id)
        #expect(home.readCelebration == 1)
        await home.readingDismissed()
        #expect(home.readCelebration == 1)
        home.selectedBook = first
        home.selectedBook = nil
        await home.readingDismissed()
        #expect(home.readCelebration == 1) // Rereading cannot trigger the reward again.
        let remaining = home.dailyReads.filter { !home.completed($0) }
        for book in remaining {
            home.selectedBook = book
            try await progress.recordEncounter(book: book, sentence: book.sentences[0])
            _ = try await progress.completeReading(book: book)
            home.selectedBook = nil
            await home.readingDismissed()
        }
        #expect(home.total == 3)
        #expect(home.dailyReadsCompleted)
        #expect(home.readCelebration == 2) // No bounce for Load 3 more books.
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
        #expect(await second.value)
        library.pending[0].resume(returning: .init(books: [sample("first")]))
        #expect(await first.value == false)
        #expect(home.books.map(\.id) == ["second"])
    }
}
