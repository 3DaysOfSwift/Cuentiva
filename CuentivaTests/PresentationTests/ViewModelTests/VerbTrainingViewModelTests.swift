import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct VerbTrainingViewModelTests {
    @Test func workoutStartsAutomaticallyAndAdvancesOnlyAfterCompletion() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress(); saved.claimedVerbGift = true
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo); try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let model = VerbTrainingViewModel(feature: VerbTrainingManager(progress: progress, purchases: purchases))
        await model.prepare()
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
