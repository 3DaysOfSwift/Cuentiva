//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct PracticeProgressTests {
    @Test func recordsPracticeWithoutAwardingExtraCoinsAcrossReload() async throws {
        let repo = MemoryProgress(), progress = ProgressManager(repository: MemoryProgress())
        let manager = ProgressManager(repository: repo); try await manager.load()
        let book = sample()
        try await manager.recordEncounter(book: book, sentence: book.sentences[0])
        #expect(manager.snapshot.bookWordBaselines?[book.id] == [])
        #expect(manager.snapshot.seenWords?.contains("café") == true)
        let receipt = try await manager.complete(book: book)
        #expect(receipt.streakCelebration == 1)
        #expect(try await manager.complete(book: book).streakCelebration == nil)
        try await manager.recordPractice(book: book, matches: 1)
        let restored = ProgressManager(repository: repo); try await restored.load()
        try await restored.recordPractice(book: book, matches: 1)
        #expect(restored.snapshot.bestMatches?[book.id] == 1)
        #expect(restored.snapshot.doubloons == 1)
        #expect(restored.snapshot.completed.count == 1)
        try await progress.load()
        await #expect(throws: (any Error).self) { try await progress.recordPractice(book: book, matches: 1) }
    }
    @Test func failedPracticeSavePreservesScoreAndCoins() async throws {
        let repo = MemoryProgress(), book = sample()
        let manager = ProgressManager(repository: repo); try await manager.load()
        try await manager.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await manager.complete(book: book)
        await repo.setFailure(true)
        await #expect(throws: (any Error).self) { try await manager.recordPractice(book: book, matches: 1) }
        #expect(manager.snapshot.doubloons == 1)
        #expect(manager.snapshot.rewardedBooks == [book.id])
        #expect(manager.snapshot.bestMatches?[book.id] == nil)
    }
    @Test func legacyProgressDoesNotInventBaseline() async throws {
        let repo = MemoryProgress()
        var old = LearnerProgress(); old.evidence = ["café": 1]
        try await repo.save(old)
        let manager = ProgressManager(repository: repo); try await manager.load()
        let book = sample(); try await manager.recordEncounter(book: book, sentence: book.sentences[0])
        #expect(manager.snapshot.bookWordBaselines?[book.id] == nil)
    }
}
