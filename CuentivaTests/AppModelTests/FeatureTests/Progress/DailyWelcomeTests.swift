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

@Suite @MainActor struct DailyWelcomeTests {
    @Test func languageTipsAlternateVisitDaysPersistAndStopWhenAllSeen() async throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryProgress()
        var progress = ProgressManager(repository: repo, now: { now })
        try await progress.load()
        let ids = LanguageTermsManager.terms.map(\.id)
        for visit in 0..<(ids.count * 2 + 2) {
            let welcome = try #require(progress.dailyWelcome)
            try await progress.acknowledgeWelcome(day: welcome.day)
            try await progress.acknowledgeWelcome(day: welcome.day)
            #expect(progress.snapshot.languageTips?.visitDays.count == visit + 1)
            let pending = progress.snapshot.languageTips?.pending
            if visit % 2 == 0 && visit / 2 < ids.count {
                #expect(pending == ids[visit / 2])
                let id = try #require(pending)
                let restored = ProgressManager(repository: repo, now: { now })
                try await restored.load(); progress = restored
                #expect(progress.snapshot.languageTips?.pending == id)
                await repo.setFailure(true)
                await #expect(throws: AppFailure.self) { try await progress.acknowledgeLanguageTip(id) }
                #expect(progress.snapshot.languageTips?.pending == id)
                await repo.setFailure(false)
                try await progress.acknowledgeLanguageTip(id)
                #expect(progress.snapshot.languageTips?.pending == nil)
            } else { #expect(pending == nil) }
            #expect(progress.snapshot.practiceDays.isEmpty)
            #expect(try ProgressRecords.decode(ProgressRecords.encode(progress.snapshot)) == progress.snapshot)
            // Missing calendar days does not skip unseen terms.
            now = now.addingTimeInterval(visit % 3 == 0 ? 3 * 86400 : 86400)
        }
        #expect(progress.snapshot.languageTips?.seen == Set(ids))
    }

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
        _ = try await progress.complete(book: book)
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
