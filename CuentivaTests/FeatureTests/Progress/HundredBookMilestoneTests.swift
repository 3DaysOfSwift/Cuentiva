import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct HundredBookMilestoneTests {
    @Test func honoursRequireSavedHundredthBookAndSurviveReload() async throws {
        let repository = MemoryProgress()
        var saved = LearnerProgress()
        saved.completed = Set((1...99).map { "book-\($0)" })
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        #expect(progress.snapshot.readerBadges.isEmpty)
        #expect(progress.snapshot.nextCompletionNumber(for: "hundred") == 100)
        #expect(progress.snapshot.nextCompletionNumber(for: "book-1") == nil)
        let book = sample("hundred")
        try await progress.recordEncounter(book: book, sentence: try #require(book.sentences.first))
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.completeReading(book: book) }
        #expect(progress.snapshot.readerBadges.isEmpty)
        await repository.setFailure(false)
        let receipt = try await progress.completeReading(book: book)
        #expect(receipt.celebratesHundredBooks)
        #expect(progress.snapshot.readerBadges == [.vip, .persistence, .onePercent])
        let repeated = try await progress.complete(book: book)
        #expect(!repeated.celebratesHundredBooks)
        let restored = ProgressManager(repository: repository)
        try await restored.load()
        #expect(restored.snapshot.readerBadges == progress.snapshot.readerBadges)
        let records = try ProgressRecords.encode(restored.snapshot)
        #expect(try ProgressRecords.decode(records).readerBadges == [.vip, .persistence, .onePercent])
        #expect(restored.snapshot.nextCompletionNumber(for: "next") == 101)
    }
}
