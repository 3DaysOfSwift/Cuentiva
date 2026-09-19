import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct ProgressTests {
    @Test func completionIsIdempotentAndSurvivesReload() async throws {
        let repository = MemoryProgress(), book = sample()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        let first = try await progress.complete(book: book), second = try await progress.complete(book: book)
        #expect(first.isNew); #expect(!second.isNew); #expect(second.total == 1)
        let restored = ProgressManager(repository: repository); try await restored.load()
        #expect(restored.snapshot.completed == [book.id]); #expect(restored.snapshot.vocabulary["estar"] == .learning)
    }
    @Test func incompleteBookCannotFinish() async throws {
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        await #expect(throws: AppFailure.self) { try await progress.complete(book: sample()) }
        #expect(progress.snapshot.completed.isEmpty)
    }
    @Test func failedPersistenceDoesNotPublishSuccess() async throws {
        let repo = MemoryProgress(), book = sample(); let progress = ProgressManager(repository: repo); try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); await repo.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.complete(book: book) }
        #expect(progress.snapshot.completed.isEmpty)
        await repo.setFailure(false); _ = try await progress.complete(book: book)
        #expect(progress.snapshot.completed.count == 1)
    }
    @Test func streakUsesCalendarDaysAndPreservesBooks() async throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = ProgressManager(repository: MemoryProgress(), now: { now }, calendar: calendar)
        let book = sample(); try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        #expect(progress.streak == 1)
        now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        #expect(progress.streak == 1)
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); #expect(progress.streak == 2)
        now = try #require(calendar.date(byAdding: .day, value: 2, to: now))
        #expect(progress.streak == 0); #expect(progress.snapshot.completed.count == 1)
    }
    @Test func exposureDoesNotBecomeKnownAutomatically() async throws {
        let progress = ProgressManager(repository: MemoryProgress()), book = sample(); try await progress.load()
        for _ in 0..<3 { try await progress.recordEncounter(book: book, sentence: book.sentences[0]) }
        #expect(progress.snapshot.vocabulary["estar"] == .learning)
        #expect(progress.snapshot.evidence["estar"] == 1)
        try await progress.setVocabulary("estar", state: .known)
        #expect(progress.snapshot.vocabulary["estar"] == .known)
    }
}
