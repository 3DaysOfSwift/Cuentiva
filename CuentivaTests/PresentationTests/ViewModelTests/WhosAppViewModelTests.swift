//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct WhosAppViewModelTests {
    @Test func lockedContactsDoNotLoadOrChargeCoins() async throws {
        let library = DelayedLibrary()
        let progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let model = WhosAppViewModel(library: library, progress: progress)
        await model.refresh()
        #expect(!model.unlocked)
        #expect(model.authors.isEmpty)
        #expect(library.pending.isEmpty)
        #expect(model.coins == 0)
    }

    @Test func unlockedContactsComeFromLibraryWithoutSpendingCoins() async throws {
        var saved = LearnerProgress()
        saved.completed = Set((0..<11).map { "book-\($0)" })
        saved.doubloons = 11
        let repository = MemoryProgress()
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let library = DelayedLibrary()
        let model = WhosAppViewModel(library: library, progress: progress)
        let loading = Task { await model.refresh() }
        try await waitUntil { library.pending.count == 1 }
        library.pending[0].resume(returning: .init(authors: [.pipa]))
        await loading.value
        #expect(model.unlocked)
        #expect(model.authors.map(\.id) == [Author.pipa.id])
        #expect(model.coins == 11)
    }
}
