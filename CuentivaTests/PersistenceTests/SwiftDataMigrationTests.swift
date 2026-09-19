import Foundation
import Testing
import CryptoKit
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct SwiftDataMigrationTests {
    private func folder() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    @Test func allProgressFieldsMigrateOnceAndResetDoesNotResurrectLegacyData() async throws {
        let directory = try folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let url = directory.appending(path: "progress.json")
        var value = LearnerProgress()
        value.selectedLearningLevel = .b2; value.completed = ["cafe"]
        value.attempts = ["cafe": ["s0", "s1"]]; value.positions = ["cafe": 2]
        value.bookArrivals = ["cafe": Date(timeIntervalSince1970: 123)]
        value.bookLastRead = value.bookArrivals; value.dailyReadingDate = Date(timeIntervalSince1970: 456)
        value.dailyReadingIDs = ["cafe"]; value.practiceDays = ["2026-09-18"]
        value.vocabulary = ["café": .known]; value.seenWords = ["café", "el"]
        value.wordHistoryComplete = true; value.bookWordBaselines = ["cafe": ["el"]]
        value.celebratedCompletionDays = ["2026-09-18"]; value.rewardedBooks = ["cafe"]
        value.bestMatches = ["cafe/s0": 3]; value.doubloons = 5; value.evidence = ["café": 2]
        let original = try JSONEncoder().encode(value); try original.write(to: url)
        let repository = LocalProgressRepository(url: url, store: store)
        #expect(try await repository.load() == value)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        value.positions["cafe"] = 3; try await repository.save(value)
        try original.write(to: url) // leftover from a previous app version
        #expect(try await LocalProgressRepository(url: url, store: store).load() == value)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        try await repository.save(.init())
        #expect(try await LocalProgressRepository(url: url, store: store).load() == LearnerProgress())
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
    @Test func sentencePositionChangesOneRecordAndFailureRollsBack() async throws {
        let directory = try folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let repository = LocalProgressRepository(url: directory.appending(path: "progress.json"), store: store)
        var value = try await repository.load(); value.positions = ["one": 1, "two": 5]
        value.vocabulary = ["árbol": .known]; try await repository.save(value)
        let before = try #require(try await store.read("progress"))
        value.positions["one"] = 2; try await repository.save(value)
        let after = try #require(try await store.read("progress"))
        #expect(after.keys.filter { after[$0] != before[$0] } == ["positions/one"])
        #expect(before.count == after.count)
        #if DEBUG
        try await store.failNextCommitForTesting()
        var failed = value; failed.positions["one"] = 99; failed.vocabulary["nuevo"] = .learning
        await #expect(throws: (any Error).self) { try await repository.save(failed) }
        #expect(try await repository.load() == value)
        try await repository.save(failed)
        #expect(try await repository.load() == failed)
        #endif
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "progress.json").path))
    }
    @Test func failedImportRetriesWithoutCreatingAnEmptyProgressStore() async throws {
        let directory = try folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let url = directory.appending(path: "progress.json")
        var value = LearnerProgress(); value.doubloons = 9
        try JSONEncoder().encode(value).write(to: url)
        let repository = LocalProgressRepository(url: url, store: store)
        #if DEBUG
        try await store.failNextCommitForTesting()
        await #expect(throws: (any Error).self) { try await repository.load() }
        #expect(try await store.read("progress") == nil)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #endif
        #expect(try await repository.load() == value)
    }
    @Test func legacyDraftsMigrateAndDeletionDoesNotReimportThem() async throws {
        let directory = try folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let url = directory.appending(path: "drafts.json")
        var draft = Contribution(); draft.title = "A saved draft"; draft.spanish = "Hola"; draft.teachingNote = "A greeting"
        try JSONEncoder().encode([draft]).write(to: url)
        let repository = LocalContributionRepository(url: url, store: store)
        #expect(try await repository.drafts() == [draft])
        try await repository.remove(draft.id)
        #expect(try await LocalContributionRepository(url: url, store: store).drafts().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
    @Test func chatMigrationPreservesOrderAndDeletionSurvivesRelaunch() async throws {
        let directory = try folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let url = directory.appending(path: "chat.json")
        let first = ChatTurn(question: "Hola", spanish: "Hola", english: "Hello", correction: "", suggestion: "¿Qué tal?")
        let second = ChatTurn(question: "Bien", spanish: "Muy bien", english: "Very well", correction: "", suggestion: "¿Y tú?")
        let legacy = ["fox": ChatConversation(turns: [first, second], memory: "Travel")]
        try JSONEncoder().encode(legacy).write(to: url)
        let repository = LocalChatRepository(url: url, store: store)
        #expect(try await repository.load()["fox"]?.turns.map(\.id) == [first.id, second.id])
        try await repository.save([:])
        #expect(try await LocalChatRepository(url: url, store: store).load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
    @Test func fantasyMigrationPreservesProfileDraftsAndPublicationAllowance() async throws {
        let directory = try folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        let url = directory.appending(path: "fantasy.json")
        let profile = FantasyProfile(creature: .fox, revealNumber: 333,
            details: .init(name: "Matt", biography: "I travel."), identity: .init(name: "Foxy", biography: "A travelling fox."))
        let story = FantasyStory(title: "El viaje", englishTitle: "The journey",
            sentences: (0..<16).map { _ in .init(spanish: "El zorro viaja.", english: "The fox travels.") })
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let publication = FantasyPublication(storyID: story.id, publishedAt: date, book: story.personalBook(author: Author.demoProfiles[0]))
        let legacy = FantasyArchive(introductionSeen: true, profile: profile, stories: [story], publications: [publication])
        try JSONEncoder().encode(legacy).write(to: url)
        let repository = LocalFantasyRepository(url: url, store: store)
        let loaded = try await repository.load()
        #expect(loaded.introductionSeen == true)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(loaded.profile == profile)
        #expect(loaded.stories == [story])
        #expect(loaded.publications?.first?.publishedAt == date)
        #expect(loaded.publications?.first?.book.id == publication.book.id)
        var updated = loaded; updated.introductionSeen = false
        try await repository.save(updated)
        #expect(try await LocalFantasyRepository(url: url, store: store).load().introductionSeen == false)
    }
}
