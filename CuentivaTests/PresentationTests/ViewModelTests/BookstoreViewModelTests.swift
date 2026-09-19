import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct BookstoreViewModelTests {
    @Test func fullCatalogueHidesCompletedByDefaultAndCanShowThemAgain() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let first = sample("first"), second = sample("second")
        let library = LibraryManager(repository: MemoryBooks(values: [first, second]), purchases: purchases, progress: progress)
        try await progress.load(); try await library.load()
        try await progress.recordEncounter(book: first, sentence: first.sentences[0])
        _ = try await progress.complete(book: first)
        let model = BookstoreViewModel(library: library, progress: progress)
        #expect(model.hideCompleted)
        #expect(!model.refreshID.query.recommendations)
        await model.refresh()
        #expect(model.books.map(\.id) == ["second"])
        model.hideCompleted = false
        await model.refresh()
        #expect(Set(model.books.map(\.id)) == ["first", "second"])
        model.query = "no matching title"
        await model.refresh()
        #expect(model.books.isEmpty)
    }
}
