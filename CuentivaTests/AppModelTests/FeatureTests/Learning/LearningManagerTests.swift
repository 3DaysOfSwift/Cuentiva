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

@Suite(.timeLimit(.minutes(1))) @MainActor struct LearningManagerTests {
    @Test func overlappingCompletionsAwardOnlyOneRewardAfterPersistence() async throws {
        let book = sample("paid")
        var initial = LearnerProgress()
        initial.attempts[book.id] = Set(book.fullText.map(\.id))
        let repository = CompletionRepository(value: initial)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases()
        purchases.hasAccess = true
        let feature = LearningManager(purchases: purchases, progress: progress)

        let first = Task { try await feature.finish(book) }
        await repository.waitForSave()
        #expect(progress.snapshot == initial)
        var secondCompletion: Task<CompletionReceipt, Error>?
        await withCheckedContinuation { (started: CheckedContinuation<Void, Never>) in
            let task = Task {
                started.resume(returning: ())
                return try await feature.finish(book)
            }
            // The caller resumes only after this MainActor task reaches its await.
            secondCompletion = task
        }
        await repository.release()
        let firstReceipt = try await first.value
        let secondTask = try #require(secondCompletion)
        let secondReceipt = try await secondTask.value
        #expect(firstReceipt.isNew)
        #expect(!secondReceipt.isNew)
        #expect(progress.snapshot.doubloons == 1)
        #expect(progress.snapshot.completed == [book.id])
        #expect(await repository.load() == progress.snapshot)
    }

    @Test func failedCompletionPreservesProgressAndRetryAwardsOnce() async throws {
        let book = sample("paid")
        var initial = LearnerProgress()
        initial.attempts[book.id] = Set(book.fullText.map(\.id))
        let repository = CompletionRepository(value: initial)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases()
        purchases.hasAccess = true
        let feature = LearningManager(purchases: purchases, progress: progress)

        let completion = Task { try await feature.finish(book) }
        await repository.waitForSave()
        await repository.release(failing: true)
        await #expect(throws: AppFailure.self) { try await completion.value }
        #expect(progress.snapshot == initial)
        #expect(await repository.load() == initial)

        await repository.release()
        #expect(try await feature.finish(book).isNew)
        #expect(!(try await feature.finish(book)).isNew)
        #expect(progress.snapshot.doubloons == 1)
        #expect(await repository.load() == progress.snapshot)
    }

    @Test func cancellationDuringSuccessfulCompletionSaveStillPublishesCommittedReward() async throws {
        let book = sample("paid")
        var initial = LearnerProgress()
        initial.attempts[book.id] = Set(book.fullText.map(\.id))
        let repository = CompletionRepository(value: initial)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases()
        purchases.hasAccess = true
        let feature = LearningManager(purchases: purchases, progress: progress)

        let completion = Task { try await feature.finish(book) }
        await repository.waitForSave()
        completion.cancel()
        #expect(progress.snapshot == initial)
        await repository.release()
        #expect(try await completion.value.isNew)
        #expect(progress.snapshot.doubloons == 1)
        #expect(await repository.load() == progress.snapshot)
        #expect(!(try await feature.finish(book)).isNew)
        #expect(progress.snapshot.doubloons == 1)
    }

    @Test func threeChaptersResumeAndCannotCompleteBeforeTheEnding() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository); try await progress.load()
        let purchases = TestPurchases()
        let feature = LearningManager(purchases: purchases, progress: progress)
        var book = sample()
        book.continuation = [.init(id: "middle", spanish: "Sigue.", english: "It continues.")]
        book.ending = [.init(id: "end1", spanish: "Llega.", english: "Arrives."),
                       .init(id: "end2", spanish: "Fin.", english: "End.")]
        await #expect(throws: AppFailure.self) { try await feature.finishChapterTwo(book) }
        let first = try await feature.advance(book: book, from: 0)
        if case .fullReading = first {} else { Issue.record("Expected Chapter 2") }
        #expect(feature.position(book) == 1)
        await #expect(throws: AppFailure.self) { try await feature.finishReading(book) }
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await feature.finishChapterTwo(book) }
        #expect(progress.snapshot.attempts[book.id] == ["s0"])
        await repository.setFailure(false)
        #expect(try await feature.finishChapterTwo(book) == 2)
        let restored = ProgressManager(repository: repository); try await restored.load()
        let resumed = LearningManager(purchases: purchases, progress: restored)
        #expect(resumed.position(book) == 2)
        #expect(restored.snapshot.completed.isEmpty)
        _ = try await resumed.advance(book: book, from: 2)
        await #expect(throws: AppFailure.self) { try await resumed.finishReading(book) }
        let last = try await resumed.advance(book: book, from: 3)
        if case .bookFinished = last {} else { Issue.record("Expected the whole-book invitation") }
        let receipt = try await resumed.finish(book)
        #expect(receipt.isNew)
        #expect(restored.snapshot.doubloons == 1)
        #expect(restored.snapshot.attempts[book.id] == Set(book.fullText.map(\.id)))
        #expect(!resumed.canRead(book))
        purchases.hasAccess = true
        #expect(!(try await resumed.finish(book)).isNew)
        #expect(restored.snapshot.doubloons == 1)
    }

    @Test func rewrittenEditionRestartsOldAttemptsWithoutErasingCompletedHistory() async throws {
        let repository = MemoryProgress()
        var saved = LearnerProgress()
        saved.positions["cafe"] = 2
        saved.attempts["cafe"] = ["old-sentence"]
        saved.completed.insert("cafe")
        saved.doubloons = 1
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = LearningManager(purchases: purchases, progress: progress)
        var revised = sample(sentences: 2)
        revised.editorialRevision = 2
        #expect(feature.position(revised) == 0)
        #expect(progress.snapshot == saved)
        _ = try await feature.advance(book: revised, from: 0)
        #expect(feature.position(revised) == 1)
        _ = try await feature.advance(book: revised, from: 1)
        let receipt = try await feature.finishReading(revised)
        #expect(!receipt.isNew)
        #expect(progress.snapshot.doubloons == 1)
        #expect(progress.snapshot.completed == ["cafe"])
    }

    @Test func movingAndFinishingRespectAccessAndCommittedProgress() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = LearningManager(purchases: purchases, progress: progress)
        let book = sample("paid", sentences: 2)
        try await feature.move(book: book, position: 1)
        #expect(feature.position(book) == 1)
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await feature.move(book: book, position: 0) }
        #expect(feature.position(book) == 1)
        await repository.setFailure(false)
        for sentence in book.sentences {
            _ = try await feature.check(book: book, sentence: sentence, answer: sentence.spanish)
        }
        let receipt = try await feature.finish(book)
        #expect(receipt.total == 1)
        #expect(feature.position(book) == 0)
        purchases.hasAccess = false
        await #expect { try await feature.move(book: book, position: 1) } throws: { error in
            guard case AppFailure.locked = error else { return false }
            return true
        }
        await #expect { try await feature.finish(book) } throws: { error in
            guard case AppFailure.locked = error else { return false }
            return true
        }
    }

    @Test func invalidOrEmptyAnswersNeverSaveAnEncounter() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases()
        let feature = LearningManager(purchases: purchases, progress: progress)
        let book = sample()
        let foreign = Sentence(id: "foreign", spanish: "Hola", english: "Hello")
        await #expect { try await feature.check(book: book, sentence: foreign, answer: "Hola") } throws: { error in
            guard case AppFailure.invalidBook = error else { return false }
            return true
        }
        await #expect { try await feature.check(book: book, sentence: book.sentences[0], answer: "   ") } throws: { error in
            guard case AppFailure.emptyAnswer = error else { return false }
            return true
        }
        #expect(await repository.saveAttempts == 0)
        #expect(progress.snapshot.completed.isEmpty)
    }
}

private actor CompletionRepository: ProgressRepository {
    private var value: LearnerProgress
    private var pending: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    private var released = false
    private var failing = false

    init(value: LearnerProgress) { self.value = value }
    func load() -> LearnerProgress { value }
    func save(_ next: LearnerProgress) async throws {
        if !released {
            await withCheckedContinuation {
                pending = $0
                arrival?.resume()
                arrival = nil
            }
        }
        if failing { throw AppFailure.unavailable("Controlled completion failure") }
        value = next
    }
    func waitForSave() async {
        if pending != nil { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func release(failing: Bool = false) {
        self.failing = failing
        released = true
        pending?.resume()
        pending = nil
    }
}
