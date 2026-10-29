//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite(.timeLimit(.minutes(1))) @MainActor struct BookstoreViewModelTests {
    @Test func olderSearchCannotReplaceNewerResults() async throws {
        let library = DelayedLibrary()
        let model = BookstoreViewModel(library: library, progress: ProgressManager(repository: MemoryProgress()))
        model.query = "older"
        let older = try await startRefresh(model)
        let oldReplyCandidate = library.pending.popLast()
        let oldReply = try #require(oldReplyCandidate)
        model.query = "newer"
        let newer = try await startRefresh(model)
        let newReplyCandidate = library.pending.popLast()
        let newReply = try #require(newReplyCandidate)
        newReply.resume(returning: LibraryPresentation(books: [sample("newer")]))
        await newer.value
        oldReply.resume(returning: LibraryPresentation(books: [sample("older")]))
        await older.value
        #expect(model.books.map(\.id) == ["newer"])
    }

    @Test func cancelledSearchDoesNotPublishLateResult() async throws {
        let library = DelayedLibrary()
        let model = BookstoreViewModel(library: library, progress: ProgressManager(repository: MemoryProgress()))
        let refresh = try await startRefresh(model)
        let replyCandidate = library.pending.popLast()
        let reply = try #require(replyCandidate)
        refresh.cancel()
        reply.resume(returning: LibraryPresentation(books: [sample("obsolete")]))
        await refresh.value
        #expect(model.books.isEmpty)
    }

    private func startRefresh(_ model: BookstoreViewModel) async throws -> Task<Void, Never> {
        var task: Task<Void, Never>?
        await withCheckedContinuation { started in
            task = Task {
                started.resume()
                await model.refresh()
            }
        }
        return try #require(task)
    }

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
