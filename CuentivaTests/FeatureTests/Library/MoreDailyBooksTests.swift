import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct MoreDailyBooksTests {
    @Test(arguments: [3, 4, 6])
    func replacesCompletedSetAtomicallyWithoutChangingProgress(bookCount: Int) async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        let purchases = TestPurchases(); purchases.hasAccess = true
        let books = (0..<bookCount).map { sample("extra-\($0)") }
        let library = LibraryManager(repository: MemoryBooks(values: books), purchases: purchases, progress: progress)
        try await library.load()
        try await library.prepareDailyReads()
        let original = await library.dailyReads
        let originalIDs = original.map(\.id)
        #expect(await !library.dailyReadsCompleted)
        try await library.loadMoreDailyReads()
        #expect(await library.dailyReads.map(\.id) == originalIDs)
        for book in original {
            try await progress.recordEncounter(book: book, sentence: try #require(book.sentences.first))
            _ = try await progress.completeReading(book: book)
        }
        #expect(await library.dailyReadsCompleted)
        let before = progress.snapshot
        if bookCount == 3 {
            await #expect(throws: AppFailure.self) { try await library.loadMoreDailyReads() }
            #expect(progress.snapshot == before)
            return
        }
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await library.loadMoreDailyReads() }
        #expect(progress.snapshot == before)
        #expect(await library.dailyReads.map(\.id) == originalIDs)
        await repository.setFailure(false)
        try await library.loadMoreDailyReads()
        let nextIDs = await library.dailyReads.map(\.id)
        #expect(nextIDs.count == min(3, bookCount - 3))
        #expect(Set(nextIDs).isDisjoint(with: originalIDs))
        #expect(await !library.dailyReadsCompleted)
        #expect(progress.snapshot.completed == before.completed)
        #expect(progress.snapshot.positions == before.positions)
        #expect(progress.snapshot.vocabulary == before.vocabulary)
        let restoredProgress = ProgressManager(repository: repository)
        let restoredLibrary = LibraryManager(repository: MemoryBooks(values: books), purchases: purchases, progress: restoredProgress)
        try await restoredLibrary.load()
        #expect(await restoredLibrary.dailyReads.map(\.id) == nextIDs)
        purchases.hasAccess = false
        await #expect(throws: AppFailure.self) { try await library.loadMoreDailyReads() }
    }
    @Test func emptyLibraryIsNotComplete() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let library = LibraryManager(repository: MemoryBooks(values: []), purchases: purchases,
            progress: ProgressManager(repository: MemoryProgress()))
        try await library.load()
        #expect(await !library.dailyReadsCompleted)
    }
}
