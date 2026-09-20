import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct CompletedViewModelTests {
    @Test func newerSearchWinsWhenResponsesFinishOutOfOrder() async throws {
        let library = DelayedLibrary()
        let model = CompletedViewModel(library: library, progress: ProgressManager(repository: MemoryProgress()))
        #expect(model.refreshID.query.completedOnly)
        model.query = "first"
        let first = Task { await model.refresh() }
        try await waitUntil { library.pending.count == 1 }
        model.query = "second"
        let second = Task { await model.refresh() }
        try await waitUntil { library.pending.count == 2 }
        var latest = LibraryPresentation(books: [sample("second")])
        latest.completedTotal = 20
        latest.practiceDays = 12
        latest.doubloons = 7
        library.pending[1].resume(returning: latest)
        await second.value
        library.pending[0].resume(returning: .init(books: [sample("first")]))
        await first.value
        #expect(model.books.map(\.id) == ["second"])
        #expect(model.total == 20)
        #expect(model.practiceDays == 12)
        #expect(model.doubloons == 7)
    }
}
