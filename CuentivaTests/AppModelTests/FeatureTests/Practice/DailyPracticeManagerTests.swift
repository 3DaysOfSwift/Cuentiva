import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct DailyPracticeManagerTests {
    @Test func everyBookCanSupplyDailyPractice() throws {
        #if canImport(CuentivaAppModel)
        let url = TestResources.repositoryRoot.appending(path: "Cuentiva/3 - App Resources/Library.dat")
        #else
        let url = try #require(Bundle.main.url(forResource: "Library", withExtension: "dat"))
        #endif
        let books = try BinaryLibrary(url: url).books()
        for index in books.indices {
            let selected = (0..<3).map { books[(index + $0) % books.count] }
            let session = try DailyPracticeSession.make(day: "2026-09-20", books: selected)
            #expect(session.valid)
            #expect(Set(session.phrases.map(\.source)) == Set(selected.map(\.englishTitle)))
            #expect(session.missingOptions.contains(session.missingAnswer))
        }
    }
    @Test func rewardIsAtomicResumableAndOncePerDay() async throws {
        let repo = MemoryProgress()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let books = (0..<3).map { sample("book\($0)", sentences: 4) }
        let progress = ProgressManager(repository: repo, now: { now })
        try await progress.load()
        try await progress.saveDailyReading(books.map(\.id), date: now)
        try await progress.prepareDailyPractice(books: books)
        let day = try #require(progress.dailyPractice?.day)
        while let session = progress.dailyPractice, !session.completed.contains(.missingWord) {
            #expect(try await progress.answerDailyPractice(session.missingAnswer, game: .missingWord, day: day))
        }
        let restored = ProgressManager(repository: repo, now: { now })
        try await restored.load()
        #expect(restored.dailyPractice?.completed.contains(.missingWord) == true)
        while let session = restored.dailyPractice, !session.completed.contains(.sentenceBuilder) {
            #expect(try await restored.answerDailyPractice(String(session.builderTokens.count), game: .sentenceBuilder, day: day))
        }
        let session = try #require(restored.dailyPractice)
        #expect(try await restored.answerDailyPractice(session.currentTrail.words[0], game: .sentenceTrail, day: day))
        await repo.setFailure(true)
        await #expect(throws: AppFailure.self) { try await restored.stopDailyTrail(day: day) }
        #expect(restored.snapshot.doubloons ?? 0 == 0)
        await repo.setFailure(false)
        try await restored.stopDailyTrail(day: day)
        #expect(restored.snapshot.doubloons == 1)
        #expect(restored.streak == 0)
        #expect(restored.snapshot.practiceDays.count == 1)
        #expect(restored.snapshot.wordExposureHistory?.count == 1)
        await #expect(throws: AppFailure.self) { try await restored.stopDailyTrail(day: day) }
        #expect(try ProgressRecords.decode(ProgressRecords.encode(restored.snapshot)) == restored.snapshot)
        now = now.addingTimeInterval(86400)
        #expect(restored.dailyPractice == nil)
        await #expect(throws: AppFailure.self) { try await restored.stopDailyTrail(day: day) }
        try await restored.saveDailyReading(books.map(\.id), date: now)
        try await restored.prepareDailyPractice(books: books)
        #expect(restored.dailyPractice?.completed.isEmpty == true)
    }
    @Test func trailReplenishesOnlyUsedTileAndResumesScenario() throws {
        var session = try DailyPracticeSession.make(day: "2026-09-20", books: (0..<3).map { sample("b\($0)", sentences: 4) })
        try session.selectScenario(.coffee)
        let before = session.trailOptions
        #expect(try session.choose("Quisiera", game: .sentenceTrail))
        #expect(zip(before, session.trailOptions).filter { $0 != $1 }.count == 1)
        #expect(session.trailOptions.contains("un"))
        #expect(throws: AppFailure.self) { try session.selectScenario(.bus) }
        let data = try JSONEncoder().encode(session)
        #expect(try JSONDecoder().decode(DailyPracticeSession.self, from: data) == session)
        let wrong = try #require(session.trailOptions.first { $0 != "un" })
        #expect(try !session.choose(wrong, game: .sentenceTrail))
        #expect(session.completed.contains(.sentenceTrail))
        #expect(throws: AppFailure.self) { try session.choose("un", game: .sentenceTrail) }
    }
}
