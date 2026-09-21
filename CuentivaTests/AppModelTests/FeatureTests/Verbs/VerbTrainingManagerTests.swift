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

@Suite @MainActor struct VerbTrainingManagerTests {
    @Test func previewFlagNeverCountsAsEarnedProgress() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress(); saved.debugVerbTrainingEnabled = true
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo); try await progress.load()
        #if DEBUG
        #expect(progress.snapshot.verbTrainingUnlocked)
        try await progress.performVerbTraining(.claimGift)
        try await progress.performVerbTraining(.select("ir/preterite/yo"))
        #expect(progress.snapshot.claimedVerbGift != true)
        #expect(progress.snapshot.practiceDays.isEmpty)
        await repo.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.setVerbTrainingPreview(false) }
        #expect(progress.snapshot.verbTrainingUnlocked)
        await repo.setFailure(false)
        try await progress.setVerbTrainingPreview(false)
        #else
        #expect(!progress.snapshot.verbTrainingPreview)
        #endif
        #expect(!progress.snapshot.verbTrainingUnlocked)
        #expect(progress.snapshot.claimedVerbGift != true)
        #expect(progress.snapshot.practiceDays.isEmpty)
        #expect(try ProgressRecords.decode(ProgressRecords.encode(progress.snapshot)) == progress.snapshot)
    }
    @Test func thirdCompletedBookUnlocksGiftAndAccessStillRequired() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress()
        saved.completed = ["first", "second"]
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo)
        try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = VerbTrainingManager(progress: progress, purchases: purchases)
        #expect(!feature.eligible)
        await #expect(throws: AppFailure.self) { try await feature.perform(.claimGift) }

        saved.completed.insert("third")
        try await repo.save(saved)
        let qualifiedProgress = ProgressManager(repository: repo)
        try await qualifiedProgress.load()
        let qualifiedFeature = VerbTrainingManager(progress: qualifiedProgress, purchases: purchases)
        #expect(qualifiedFeature.eligible)
        purchases.hasAccess = false
        await #expect(throws: AppFailure.self) { try await qualifiedFeature.perform(.claimGift) }
        purchases.hasAccess = true
        await repo.setFailure(true)
        await #expect(throws: AppFailure.self) { try await qualifiedFeature.perform(.claimGift) }
        #expect(!qualifiedFeature.claimed)
        await repo.setFailure(false)
        try await qualifiedFeature.perform(.claimGift)
        try await qualifiedFeature.perform(.claimGift)
        #expect(qualifiedFeature.claimed)
        #expect(qualifiedProgress.snapshot.availableChatCoins == 0)
        let reopened = ProgressManager(repository: repo); try await reopened.load()
        #expect(reopened.snapshot.verbTrainingUnlocked)
        #expect(reopened.snapshot.claimedVerbGift == true)
        #expect(reopened.streak == 0)
    }

    @Test func cloudResumesFailedSavesRetryAndRepeatedSentencesCostNothing() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress(); saved.claimedVerbGift = true; saved.doubloons = 8; saved.streakDays = []
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo); try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = VerbTrainingManager(progress: progress, purchases: purchases)
        try await feature.perform(.select("ir/preterite/yo"))
        let original = feature.state
        let phrase = try #require(original.phrase)
        let wrong = try #require(original.cloud.first { $0 != phrase.words[0] })
        #expect(try await !feature.perform(.choose(wrong, round: original.roundID, index: 0)))
        #expect(feature.state == original)
        await repo.setFailure(true)
        await #expect(throws: AppFailure.self) { try await feature.perform(.choose(phrase.words[0], round: original.roundID, index: 0)) }
        #expect(feature.state == original)
        await repo.setFailure(false)
        #expect(try await feature.perform(.choose(phrase.words[0], round: original.roundID, index: 0)))
        #expect(feature.state.cloud.count == phrase.words.count * 2)
        #expect(original.cloud == feature.state.cloud)
        #expect(feature.state.usedTiles?.count == 1)
        let restored = ProgressManager(repository: repo); try await restored.load()
        let resumed = VerbTrainingManager(progress: restored, purchases: purchases)
        #expect(resumed.state.position == 1)
        for _ in 0..<2 {
            while !resumed.state.finished {
                let state = resumed.state
                let phrase = try #require(state.phrase)
                #expect(try await resumed.perform(.choose(phrase.words[state.position], round: state.roundID, index: state.position)))
            }
            let state = resumed.state
            await #expect(throws: AppFailure.self) { try await resumed.perform(.choose("Yo", round: state.roundID, index: 0)) }
            if resumed.state.total == 1 { try await resumed.perform(.select("ir/preterite/yo")) }
        }
        #expect(resumed.state.total == 2)
        #expect(resumed.state.repetitions[phrase.id] == 2)
        #expect(restored.snapshot.availableChatCoins == 8)
        #expect(restored.streak == 0)
        #expect(restored.snapshot.practiceDays.count == 1)
        #expect(restored.snapshot.seenWords?.contains("fui") == true)
        #expect(try ProgressRecords.decode(ProgressRecords.encode(restored.snapshot)) == restored.snapshot)
        purchases.hasAccess = false
        await #expect(throws: AppFailure.self) { try await resumed.perform(.select("ir/future/yo")) }
        #expect(resumed.state.total == 2)
    }

    @Test func staleTilesCannotModifyNewSentenceAndResetRemovesGift() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress(); saved.claimedVerbGift = true
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo); try await progress.load()
        try await progress.performVerbTraining(.select("comer/preterite/ella"))
        let old = try #require(progress.snapshot.verbTraining)
        try await progress.performVerbTraining(.select("pagar/future/yo"))
        await #expect(throws: AppFailure.self) { try await progress.performVerbTraining(.choose("Ella", round: old.roundID, index: 0)) }
        #expect(progress.snapshot.verbTraining?.position == 0)
        try await progress.reset()
        #expect(!progress.snapshot.verbTrainingUnlocked)
        #expect(progress.snapshot.verbTraining == nil)
    }
}
