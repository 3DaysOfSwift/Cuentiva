import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct ProgressTests {
    @Test func dailyBonusRequiresCompletionAndIsOncePerDayAcrossReload() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryProgress(), book = sample()
        let progress = ProgressManager(repository: repo, now: { now }, calendar: calendar)
        try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        #expect(progress.streak == 0)
        #expect(try await progress.complete(book: book).streakBonus == 0)
        now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        #expect(progress.streak == 1)
        await repo.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.complete(book: book) }
        #expect(progress.snapshot.doubloons == 1)
        await repo.setFailure(false)
        #expect(try await progress.complete(book: book).streakBonus == 1)
        #expect(progress.streak == 2)
        let restored = ProgressManager(repository: repo, now: { now }, calendar: calendar)
        try await restored.load()
        #expect(try await restored.complete(book: book).streakBonus == 0)
        #expect(restored.snapshot.doubloons == 2)
        now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        #expect(try await restored.complete(book: book).streakBonus == 1)
        #expect(restored.snapshot.doubloons == 3)
        #expect(try ProgressRecords.decode(ProgressRecords.encode(restored.snapshot)) == restored.snapshot)
    }

    @Test(arguments: [false, true]) func revivalCostsFourRequiresTodaysBookAndCannotRepeat(readFirst: Bool) async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryProgress(), book = sample()
        var saved = LearnerProgress(); saved.doubloons = 10
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo, now: { now }, calendar: calendar)
        try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        now = try #require(calendar.date(byAdding: .day, value: 2, to: now))
        #expect(progress.streak == 0)
        #expect(progress.canReviveStreak)
        if readFirst { _ = try await progress.complete(book: book) }
        await repo.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.reviveStreak() }
        #expect(progress.snapshot.doubloons == 11)
        await repo.setFailure(false)
        try await progress.reviveStreak()
        #expect(!progress.canReviveStreak)
        let revived = try #require(progress.week.first { $0.revived })
        #expect(!revived.practiced)
        #expect(!revived.today)
        #expect(progress.revivalNeedsBook == !readFirst)
        #expect(progress.streak == (readFirst ? 2 : 0))
        #expect(progress.snapshot.doubloons == (readFirst ? 8 : 7))
        await #expect(throws: AppFailure.self) { try await progress.reviveStreak() }
        let restored = ProgressManager(repository: repo, now: { now }, calendar: calendar)
        try await restored.load()
        _ = try await restored.complete(book: book)
        #expect(restored.streak == 2)
        #expect(restored.snapshot.doubloons == 8)
        #expect(restored.snapshot.practiceDays.count == 2)
        #expect(!restored.revivalNeedsBook)
        #expect(try ProgressRecords.decode(ProgressRecords.encode(restored.snapshot)) == restored.snapshot)
    }

    @Test func revivalExpiresAndInsufficientFundsDoNotChangeProgress() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = ProgressManager(repository: MemoryProgress(), now: { now }, calendar: calendar)
        try await progress.load()
        let book = sample()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        now = try #require(calendar.date(byAdding: .day, value: 2, to: now))
        #expect(progress.canReviveStreak)
        await #expect(throws: AppFailure.self) { try await progress.reviveStreak() }
        #expect(progress.snapshot.doubloons == 1)
        now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        #expect(!progress.canReviveStreak)
        await #expect(throws: AppFailure.self) { try await progress.reviveStreak() }
        #expect(try await progress.complete(book: book).streakBonus == 0)
        #expect(progress.streak == 1)
    }

    @Test func paidRevivalWithoutTodaysBookExpiresAtMidnight() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryProgress(), book = sample()
        var saved = LearnerProgress(); saved.doubloons = 4
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo, now: { now }, calendar: calendar)
        try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        now = try #require(calendar.date(byAdding: .day, value: 2, to: now))
        try await progress.reviveStreak()
        #expect(progress.revivalNeedsBook)
        now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        #expect(progress.streak == 0)
        #expect(!progress.canReviveStreak)
        #expect(!progress.revivalNeedsBook)
        #expect(try await progress.complete(book: book).streakBonus == 0)
        #expect(progress.streak == 1)
        #expect(progress.snapshot.doubloons == 1)
    }

    @Test func overlappingCompletionsAwardOneDailyBonus() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = ProgressManager(repository: MemoryProgress(), now: { now }, calendar: calendar)
        try await progress.load()
        let book = sample()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        async let first = progress.complete(book: book)
        async let second = progress.complete(book: book)
        let receipts = try await [first, second]
        #expect(receipts.map(\.streakBonus).reduce(0, +) == 1)
        #expect(progress.snapshot.doubloons == 2)
    }

    @Test func automaticLibraryCheckIsDailyPersistentAndDuplicateSafe() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryProgress()
        let progress = ProgressManager(repository: repo, now: { now }, calendar: calendar)
        try await progress.load()
        await repo.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.claimAutomaticLibraryCheck() }
        #expect(progress.snapshot.lastAutomaticLibraryCheckDay == nil)
        await repo.setFailure(false)
        async let first = progress.claimAutomaticLibraryCheck()
        async let second = progress.claimAutomaticLibraryCheck()
        let claims = try await [first, second]
        #expect(claims.filter { $0 }.count == 1)
        let restored = ProgressManager(repository: repo, now: { now }, calendar: calendar)
        try await restored.load()
        #expect(try await restored.claimAutomaticLibraryCheck() == false)
        #expect(try ProgressRecords.decode(ProgressRecords.encode(restored.snapshot)) == restored.snapshot)
        now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        #expect(try await restored.claimAutomaticLibraryCheck())
        #expect(try await restored.claimAutomaticLibraryCheck() == false)
    }

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
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); #expect(progress.streak == 1)
        _ = try await progress.complete(book: book); #expect(progress.streak == 2)
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
