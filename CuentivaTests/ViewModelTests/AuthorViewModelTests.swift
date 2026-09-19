import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct AuthorViewModelTests {
    @Test func cancelledRefreshCannotReplaceDisplayedBooks() async throws {
        let library = DelayedLibrary()
        let progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let author = Author.demoProfiles[0]
        let model = AuthorViewModel(author: author, library: library, progress: progress)
        #expect(model.refreshID.query.authorID == author.id)
        let first = Task { await model.refresh() }
        try await waitUntil { library.pending.count == 1 }
        library.pending[0].resume(returning: .init(books: [sample("visible")]))
        await first.value
        let cancelled = Task { await model.refresh() }
        try await waitUntil { library.pending.count == 2 }
        cancelled.cancel()
        library.pending[1].resume(returning: .init(books: [sample("cancelled")]))
        await cancelled.value
        #expect(model.books.map(\.id) == ["visible"])
        let book = sample("visible")
        #expect(!model.completed(book))
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        #expect(model.completed(book))
    }
}
