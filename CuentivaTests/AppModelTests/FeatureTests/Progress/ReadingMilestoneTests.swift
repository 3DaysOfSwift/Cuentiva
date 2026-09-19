import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct ReadingMilestoneTests {
    @Test func distinctCompletionsUnlockWritingAndSurviveStorage() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        for number in 1...15 {
            let book = sample("milestone-\(number)")
            let sentence = try #require(book.sentences.first)
            try await progress.recordEncounter(book: book, sentence: sentence)
            // Exercise both completion paths.
            let receipt = number.isMultiple(of: 2)
                ? try await progress.complete(book: book)
                : try await progress.completeReading(book: book)
            #expect(progress.snapshot.writingUnlocked == (number >= 5))
            #expect(receipt.unlocksWriting == (number == 5))
            #expect(receipt.requestsReview == (number == 15))
            let repeated = try await progress.completeReading(book: book)
            #expect(!repeated.unlocksWriting)
            #expect(!repeated.requestsReview)
            #expect(repeated.total == number)
        }
        let restored = ProgressManager(repository: repository)
        try await restored.load()
        #expect(restored.snapshot.writingUnlocked)
        let rows = try ProgressRecords.encode(restored.snapshot)
        #expect(try ProgressRecords.decode(rows).writingUnlocked)
        try await restored.reset()
        #expect(!restored.snapshot.writingUnlocked)
    }
    @Test func failedFifthCompletionCannotUnlockWriting() async throws {
        let repository = MemoryProgress()
        var saved = LearnerProgress()
        saved.completed = ["one", "two", "three", "four"]
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let book = sample("five")
        try await progress.recordEncounter(book: book, sentence: try #require(book.sentences.first))
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.completeReading(book: book) }
        #expect(!progress.snapshot.writingUnlocked)
        await repository.setFailure(false)
        let receipt = try await progress.completeReading(book: book)
        #expect(receipt.unlocksWriting)
        #expect(progress.snapshot.writingUnlocked)
    }
    @Test func settingsReviewLinkUsesTheAppStoreRecord() throws {
        let url = try #require(ReadingMilestones.reviewURL)
        #expect(url.host == "apps.apple.com")
        #expect(url.path == "/app/id6813381807")
        #expect(url.query == "action=write-review")
    }
}
