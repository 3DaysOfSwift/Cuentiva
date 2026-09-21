//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct VerbTrainingViewModelTests {
    @Test func workoutWaitsForStartAndAdvancesOnlyAfterCompletion() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress(); saved.claimedVerbGift = true
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo); try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let model = VerbTrainingViewModel(feature: VerbTrainingManager(progress: progress, purchases: purchases))
        await model.prepare()
        #expect(model.state.phrase == nil)
        await model.start()
        let original = model.state
        let phrase = try #require(original.phrase)
        await model.next()
        #expect(model.error != nil && model.state == original)
        await repo.setFailure(true)
        await model.choose(phrase.words[0])
        #expect(model.error != nil && model.state == original && !model.busy)
        await repo.setFailure(false)
        for word in phrase.words { await model.choose(word) }
        #expect(model.state.finished && model.state.total == 1)
        #expect(model.feedback == nil)
        #expect(model.trail.isEmpty) // Current solution is already visible above Next.
        await model.next()
        #expect(model.state.rep == 2)
        #expect(model.state.phraseID != original.phraseID)
        #expect(model.trail == [phrase.id])
        #expect(model.state.position == 0)
        let resumed = VerbTrainingViewModel(feature: VerbTrainingManager(progress: progress, purchases: purchases))
        await resumed.prepare()
        #expect(resumed.state == model.state)
    }
    @Test func completedWorkoutReturnsToSummaryUntilNextDay() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress(); saved.claimedVerbGift = true
        try await repo.save(saved)
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = ProgressManager(repository: repo, now: { now }); try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = VerbTrainingManager(progress: progress, purchases: purchases)
        let model = VerbTrainingViewModel(feature: feature)
        await model.prepare(); await model.start()
        for rep in 0..<12 {
            let phrase = try #require(model.state.phrase)
            for word in phrase.words { await model.choose(word) }
            if rep < 11 { await model.next() }
        }
        #expect(model.state.setComplete && model.summary.count == 12)
        #expect(model.awaitingCompletion)
        model.completeTraining()
        #expect(model.showingCelebration)
        await repo.setFailure(true)
        await model.continueFromCelebration()
        #expect(model.showingCelebration && model.error != nil && model.awaitingCompletion)
        await repo.setFailure(false)
        await model.continueFromCelebration()
        #expect(!model.showingCelebration && !model.awaitingCompletion)
        let reopened = VerbTrainingViewModel(feature: feature)
        await reopened.prepare()
        #expect(reopened.state.setComplete && reopened.summary == model.summary)
        #expect(!reopened.awaitingCompletion)
        now = now.addingTimeInterval(86400)
        await reopened.prepare()
        #expect(reopened.state.phrase == nil && !reopened.state.setComplete)
        #expect(reopened.state.total == 12)
        await repo.setFailure(true)
        await reopened.start()
        #expect(reopened.error != nil && reopened.state.phrase == nil)
        await repo.setFailure(false)
        await reopened.start()
        #expect(reopened.state.phrase != nil && reopened.state.rep == 1)
        #expect(!reopened.state.isFocused)
    }
    @Test func trailShowsOnlyTwelvePreviousSentencesNewestFirst() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress(); saved.claimedVerbGift = true
        var workout = VerbTrainingState()
        try workout.prepare()
        let phrase = try #require(workout.phrase)
        let earlier = (1...15).map { "previous-\($0)" }
        workout.history = earlier + [phrase.id]
        workout.position = phrase.words.count
        workout.repetitions = [phrase.id: 16]
        saved.verbTraining = workout
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo); try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let model = VerbTrainingViewModel(feature: VerbTrainingManager(progress: progress, purchases: purchases))
        #expect(model.trail == Array(earlier.suffix(12).reversed()))
        await model.next()
        #expect(model.trail == Array((earlier + [phrase.id]).suffix(12).reversed()))
        #expect(model.state.history.count == 16 && model.state.total == 16)
    }
    @Test func giftCelebratesOnlyAfterSuccessThenPreparesFirstRep() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress(); saved.practiceDays = Set((1...20).map { String(format: "2026-01-%02d", $0) })
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo); try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let model = VerbTrainingViewModel(feature: VerbTrainingManager(progress: progress, purchases: purchases))
        await repo.setFailure(true)
        await model.openGift()
        #expect(model.error != nil && !model.giftCelebrated)
        await repo.setFailure(false)
        await model.openGift()
        #expect(model.giftCelebrated)
        await model.enterGift()
        #expect(!model.giftCelebrated && model.state.phrase != nil)
    }
}
