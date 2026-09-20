import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct StatsViewModelTests {
    @Test func rollingPracticeCountsAndExposureHistory() async throws {
        let repo = MemoryProgress()
        var saved = LearnerProgress()
        saved.practiceDays = ["2026-09-20", "2026-08-22", "2026-08-21", "2025-09-21", "2025-09-20"]
        saved.seenWords = ["hola", "café", "ayer"]
        saved.wordExposureHistory = ["2026-09-19": 2, "2026-09-20": 3]
        try await repo.save(saved)
        let progress = ProgressManager(repository: repo)
        try await progress.load()
        let model = StatsViewModel(progress: progress)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let now = try #require(formatter.date(from: "2026-09-20"))
        #expect(model.daysPractised(inLast: 30, now: now) == 2)
        #expect(model.daysPractised(inLast: 365, now: now) == 4)
        #expect(model.practiceDays == 5)
        #expect(model.exposedWords == 3)
        #expect(model.exposureHistory.map(\.count) == [2, 3])
    }
    @Test func statisticsReflectSavedPracticeAndAvoidDuplicateRewards() async throws {
        let progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let stats = StatsViewModel(progress: progress)
        #expect(stats.firstPractice == nil)
        #expect(stats.booksRead == 0)
        #expect(stats.doubloons == 0)
        let book = sample()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        try await progress.recordPractice(book: book, matches: 1)
        try await progress.recordPractice(book: book, matches: 1)
        #expect(stats.booksRead == 1)
        #expect(stats.doubloons == 1)
        #expect(stats.streak == 1)
        #expect(stats.practiceDays == 1)
        #expect(stats.firstPractice != nil)
    }
}
