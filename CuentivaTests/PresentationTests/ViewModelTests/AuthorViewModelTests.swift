import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct AuthorViewModelTests {
    @Test func chatInvitationReflectsWalletAndDeviceEligibility() async throws {
        var value = LearnerProgress()
        value.completed = Set((0..<11).map { "read-\($0)" })
        value.doubloons = 3
        let repository = MemoryProgress()
        try await repository.save(value)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let library = DelayedLibrary()
        let author = Author.demoProfiles[0]
        let supported = AuthorViewModel(author: author, library: library, progress: progress, supportsChat: true)
        let unsupported = AuthorViewModel(author: author, library: library, progress: progress, supportsChat: false)
        #expect(supported.chatUnlocked)
        #expect(!unsupported.chatUnlocked)
        #expect(supported.doubloons == 3)
        try await progress.payForChat { true }
        #expect(supported.doubloons == 2)
    }

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
