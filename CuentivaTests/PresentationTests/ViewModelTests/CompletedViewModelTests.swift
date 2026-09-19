import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct CompletedViewModelTests {
    @Test func newerSearchWinsWhenResponsesFinishOutOfOrder() async throws {
        let library = DelayedLibrary()
        let model = CompletedViewModel(library: library)
        #expect(model.refreshID.query.completedOnly)
        model.query = "first"
        let first = Task { await model.refresh() }
        try await waitUntil { library.pending.count == 1 }
        model.query = "second"
        let second = Task { await model.refresh() }
        try await waitUntil { library.pending.count == 2 }
        library.pending[1].resume(returning: .init(books: [sample("second")]))
        await second.value
        library.pending[0].resume(returning: .init(books: [sample("first")]))
        await first.value
        #expect(model.books.map(\.id) == ["second"])
    }
}
