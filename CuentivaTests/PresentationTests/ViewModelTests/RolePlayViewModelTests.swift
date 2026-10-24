import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct RolePlayViewModelTests {
    @Test func emptyStorytellersDoNotInventAPreviousScenario() async throws {
        let library = DelayedLibrary()
        let repository = MemoryProgress()
        var saved = LearnerProgress()
        saved.completed = ["one", "two"]
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let model = RolePlayViewModel(library: library, progress: progress)
        let first = try #require(ConversationScenario.catalogue.first)
        #expect(model.isUnlocked(first))
        #expect(model.author(at: 0) == nil)
        #expect(model.author(at: -1) == nil)
        let next = try #require(ConversationScenario.catalogue.dropFirst().first)
        #expect(!model.isUnlocked(next))
        #expect(model.lockReason(for: next).contains(first.title))
        let load = Task { await model.refresh() }
        try await waitUntil { library.pending.count == 1 }
        library.pending[0].resume(returning: .init(authors: []))
        await load.value
        #expect(model.author(at: 0) == nil)
        #expect(model.isUnlocked(first))
    }
}
