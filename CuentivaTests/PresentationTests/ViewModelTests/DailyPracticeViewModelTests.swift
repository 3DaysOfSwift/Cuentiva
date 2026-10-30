//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct DailyPracticeViewModelTests {
    @Test(.timeLimit(.minutes(1)), arguments: [false, true], [false, true])
    func pendingAnswerCannotAdvanceTwiceAndFailedSaveCanRetry(fail: Bool, cancel: Bool) async throws {
        let repository = HeldDailyPracticeSave()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let books = (0..<3).map { sample("held\($0)", sentences: 4) }
        try await progress.saveDailyReading(books.map(\.id), date: .now)
        let purchases = TestPurchases()
        purchases.hasAccess = true
        let feature = DailyPracticeManager(progress: progress, purchases: purchases)
        let model = DailyPracticeViewModel(books: books, feature: feature)
        await model.prepare().value
        model.select(.missingWord)
        let answer = try #require(model.session?.missingAnswer)
        await repository.holdNextSave(failing: fail)
        let first = model.choose(answer)
        await repository.waitForSave()
        #expect(model.busy)
        #expect(model.session?.missingIndex == 0)
        let repeated = model.choose(answer)
        #expect(repeated == first)
        #expect(await repository.heldWrites == 1)
        if cancel { first.cancel() }
        await repository.release()
        await first.value
        #expect(!model.busy)
        #expect(model.session?.missingIndex == (fail ? 0 : 1))
        #expect(await repository.value.dailyPracticeSession?.missingIndex == (fail ? 0 : 1))
        if fail {
            #expect(model.error != nil)
            #expect(model.celebrationID == nil)
            await model.choose(answer).value
            #expect(model.error == nil)
            #expect(model.session?.missingIndex == 1)
        }
        #expect(model.celebrationID != nil)
        #expect(progress.snapshot.doubloons == nil || progress.snapshot.doubloons == 0)
    }

    @Test func cancelledAnswerBeforeDispatchDoesNotChangeRoundAndAllowsRetry() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let books = (0..<3).map { sample("cancel\($0)", sentences: 4) }
        try await progress.saveDailyReading(books.map(\.id), date: .now)
        let purchases = TestPurchases()
        purchases.hasAccess = true
        let feature = DailyPracticeManager(progress: progress, purchases: purchases)
        let model = DailyPracticeViewModel(books: books, feature: feature)
        await model.prepare().value
        model.select(.missingWord)
        let answer = try #require(model.session?.missingAnswer)
        let previousSaves = await repository.saveAttempts
        let cancelled = model.choose(answer)
        #expect(model.busy)
        cancelled.cancel()
        await cancelled.value
        #expect(model.session?.missingIndex == 0)
        #expect(await repository.saveAttempts == previousSaves)
        #expect(model.error == nil)
        #expect(!model.busy)
        await model.choose(answer).value
        #expect(model.session?.missingIndex == 1)
    }

    @Test func eachFinishedSentenceCelebratesAndFinalCounterReachesFive() async throws {
        let repo = MemoryProgress()
        let progress = ProgressManager(repository: repo); try await progress.load()
        let books = (0..<3).map { sample("b\($0)", sentences: 4) }
        try await progress.saveDailyReading(books.map(\.id), date: .now)
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = DailyPracticeManager(progress: progress, purchases: purchases)
        let model = DailyPracticeViewModel(books: books, feature: feature)
        await model.prepare().value; model.select(.sentenceBuilder)
        let rounds = try #require(model.session?.rounds)
        for round in 0..<rounds {
            let phrase = try #require(model.session?.builderPhrase)
            for index in phrase.words.indices {
                await model.choose(String(index)).value
                if index < phrase.words.count - 1 { #expect(model.celebrationID == nil) }
            }
            #expect(model.celebrationID != nil && model.completedRounds == round)
            // Leaving during the celebration must not lose or repeat saved progress.
            let animation = Task { await model.celebrateRound() }
            animation.cancel()
            await animation.value
            #expect(model.celebrationID == nil && model.completedRounds == round + 1)
        }
        #expect(model.session?.completed.contains(.sentenceBuilder) == true)
        #expect(model.completedRounds == 5)
        #expect(!model.showingReward)
        #expect(progress.snapshot.doubloons == 1)
        model.completePractice()
        #expect(model.showingReward)
        model.completePractice()
        #expect(progress.snapshot.doubloons == 1)
        let resumed = DailyPracticeViewModel(books: books, feature: feature)
        resumed.selected = .sentenceBuilder
        #expect(resumed.completedRounds == 5)
        resumed.select(.sentenceBuilder)
        resumed.completePractice()
        #expect(resumed.showingReward && progress.snapshot.doubloons == 1)
    }
    @Test func unavailableAccessAndFailedSavesRemainRetryable() async throws {
        let repo = MemoryProgress()
        let progress = ProgressManager(repository: repo)
        try await progress.load()
        let books = (0..<3).map { sample("b\($0)", sentences: 4) }
        try await progress.saveDailyReading(books.map(\.id), date: .now)
        let purchases = TestPurchases()
        purchases.hasAccess = false
        let feature = DailyPracticeManager(progress: progress, purchases: purchases)
        let model = DailyPracticeViewModel(books: books, feature: feature)
        await model.prepare().value
        #expect(model.error != nil)
        #expect(model.session == nil)
        purchases.hasAccess = true
        await model.prepare().value
        model.select(.missingWord)
        let answer = try #require(model.session?.missingAnswer)
        await repo.setFailure(true)
        await model.choose(answer).value
        #expect(model.error != nil)
        #expect(model.session?.missingIndex == 0)
        #expect(!model.busy)
        #expect(model.celebrationID == nil && model.completedRounds == 0)
        await repo.setFailure(false)
        await model.choose(answer).value
        #expect(model.error == nil)
        #expect(model.session?.missingIndex == 1)
        #expect(model.feedback == nil)
        #expect(model.celebrationID != nil && model.completedRounds == 0)
        #expect(model.displayedSession?.missingIndex == 0)
        await model.choose(answer).value
        #expect(model.session?.missingIndex == 1)
        await model.celebrateRound()
        #expect(model.celebrationID == nil && model.completedRounds == 1)
        #expect(model.displayedSession?.missingIndex == 1)
    }
}

private actor HeldDailyPracticeSave: ProgressRepository {
    private(set) var value = LearnerProgress()
    private(set) var heldWrites = 0
    private var hold = false
    private var failing = false
    private var pending: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    func load() -> LearnerProgress { value }
    func save(_ next: LearnerProgress) async throws {
        if hold {
            heldWrites += 1
            await withCheckedContinuation {
                pending = $0
                arrival?.resume()
                arrival = nil
            }
            if failing { throw AppFailure.unavailable("Controlled practice save failure") }
        }
        value = next
    }
    func holdNextSave(failing: Bool) {
        self.failing = failing
        hold = true
    }
    func waitForSave() async {
        if pending != nil { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func release() {
        hold = false
        pending?.resume()
        pending = nil
    }
}
