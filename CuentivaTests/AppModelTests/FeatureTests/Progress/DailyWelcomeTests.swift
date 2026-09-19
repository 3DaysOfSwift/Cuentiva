import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct DailyWelcomeTests {
    @Test func welcomePersistsWithoutAwardingPracticeAndReturnsNextDay() async throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository, now: { now }, calendar: calendar)
        #expect(progress.dailyWelcome == nil)
        try await progress.load()
        let first = try #require(progress.dailyWelcome)
        #expect(first.streak == 0)
        #expect(first.nextDay == 1)
        #expect(!first.startsNewStreak)
        try await progress.acknowledgeWelcome(day: first.day)
        #expect(progress.dailyWelcome == nil)
        #expect(progress.snapshot.practiceDays.isEmpty)
        #expect(progress.snapshot.completed.isEmpty)
        let decoded = try ProgressRecords.decode(ProgressRecords.encode(progress.snapshot))
        #expect(decoded.lastWelcomeDay == first.day)
        let restored = ProgressManager(repository: repository, now: { now }, calendar: calendar)
        try await restored.load()
        #expect(restored.dailyWelcome == nil)
        now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        #expect(restored.dailyWelcome != nil)
        try await restored.acknowledgeWelcome(day: first.day)
        #expect(restored.dailyWelcome != nil) // An old screen cannot acknowledge a different day.
    }

    @Test func readingTodayYesterdayAndBrokenStreakHaveDistinctWelcomes() async throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let progress = ProgressManager(repository: MemoryProgress(), now: { now }, calendar: calendar)
        try await progress.load()
        let book = sample()
        try await progress.recordEncounter(book: book, sentence: #require(book.sentences.first))
        let today = try #require(progress.dailyWelcome)
        #expect(today.practicedToday)
        #expect(today.nextDay == 1)
        now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        let tomorrow = try #require(progress.dailyWelcome)
        #expect(!tomorrow.practicedToday)
        #expect(tomorrow.streak == 1)
        #expect(tomorrow.nextDay == 2)
        now = try #require(calendar.date(byAdding: .day, value: 2, to: now))
        #expect(progress.dailyWelcome?.startsNewStreak == true)
        #expect(progress.dailyWelcome?.streak == 0)
    }

    @Test func failedAcknowledgementCanRetry() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let welcome = try #require(progress.dailyWelcome)
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.acknowledgeWelcome(day: welcome.day) }
        #expect(progress.dailyWelcome == welcome)
        await repository.setFailure(false)
        try await progress.acknowledgeWelcome(day: welcome.day)
        #expect(progress.dailyWelcome == nil)
    }
}
