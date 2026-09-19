import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct StatsViewModelTests {
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
