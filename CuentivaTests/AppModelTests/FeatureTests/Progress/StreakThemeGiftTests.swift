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

@Suite @MainActor struct StreakThemeGiftTests {
    @Test func firstTenDayStreakEarnsOnePermanentGiftWithoutVIPMembership() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository, now: { now }, calendar: calendar)
        try await progress.load()
        let book = sample()
        let sentence = try #require(book.sentences.first)
        for day in 1...9 {
            try await progress.recordEncounter(book: book, sentence: sentence)
            _ = try await progress.complete(book: book)
            #expect(progress.streak == day)
            #expect(!progress.snapshot.earnedThemePacks.contains(.vip))
            now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        }
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await progress.recordEncounter(book: book, sentence: sentence) }
        #expect(progress.snapshot.earnedStreakTheme != true)
        await repository.setFailure(false)
        try await progress.recordEncounter(book: book, sentence: sentence)
        #expect(progress.streak == 9)
        let receipt = try await progress.completeReading(book: book)
        #expect(progress.streak == 10)
        #expect(progress.snapshot.earnedThemePacks.contains(.vip))
        #expect(!progress.snapshot.isVIP)
        #expect(!progress.snapshot.availableThemes.contains(.vip))
        let earned = try ProgressRecords.decode(ProgressRecords.encode(progress.snapshot))
        #expect(earned.earnedThemePacks.contains(.vip))
        #expect(receipt.streakThemeGift == .vip)
        let duplicate = try await progress.complete(book: book)
        #expect(duplicate.streakThemeGift == nil)
        now = try #require(calendar.date(byAdding: .day, value: 20, to: now))
        let restored = ProgressManager(repository: repository, now: { now }, calendar: calendar)
        try await restored.load()
        #expect(restored.streak == 0)
        try await restored.installThemePack(.vip)
        #expect(restored.snapshot.availableThemes == [.library, .midnight, .vip])
        #expect(!restored.snapshot.isVIP)
        try await restored.reset()
        for _ in 1...10 {
            try await restored.recordEncounter(book: book, sentence: sentence)
            _ = try await restored.complete(book: book)
            now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        }
        let later = try await restored.completeReading(book: book)
        #expect(later.streakThemeGift == nil)
        #expect(restored.snapshot.hasInstalled(.vip))
    }
}
