import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct PersonalPublicationTests {
    @Test func foxHasEightOfTenDrawTickets() {
        let outcomes = (1...10).map(FantasyCreature.weightedDraw)
        #expect(outcomes.filter { $0 == .fox }.count == 8)
        #expect(outcomes.filter { $0 == .turtle }.count == 1)
        #expect(outcomes.filter { $0 == .unicorn }.count == 1)
    }
    private func prepared(_ repository: FantasyTestRepository, now: @escaping () -> Date = Date.init) async throws -> FantasyManager {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let manager = FantasyManager(repository: repository, generator: FantasyTestGenerator(), draw: { .fox }, now: now, calendar: calendar)
        try await manager.load()
        _ = try await manager.drawCreature()
        try await manager.createIdentity(name: "Matt", biography: "I travel and make apps.")
        return manager
    }
    @Test func weeklyPublicationIsPersistentAndDuplicateSafe() async throws {
        let repository = FantasyTestRepository()
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        let manager = try await prepared(repository, now: { date })
        let first = try await manager.createStory(memory: "A dance")
        let second = try await manager.createStory(memory: "A journey")
        #expect(manager.publishedBooks.isEmpty)
        let book = try await manager.publish(first)
        #expect(book.storyteller.name == "Lirio")
        #expect(book.storyteller.portrait == "SpiritFox")
        #expect(book.sentences.count == 16)
        #expect(Set(book.sentences.map(\.id)).count == 16)
        #expect(!book.vocabulary.isEmpty)
        #expect(try await manager.publish(first).id == book.id)
        await #expect(throws: AppFailure.self) { _ = try await manager.publish(second) }
        let restored = FantasyManager(repository: repository, generator: FantasyTestGenerator(), now: { date })
        try await restored.load()
        #expect(restored.publishedBooks.map(\.id) == [book.id])
        await #expect(throws: AppFailure.self) { _ = try await restored.publish(second) }
        date = date.addingTimeInterval(7 * 24 * 60 * 60)
        _ = try await manager.publish(second)
        #expect(manager.publishedBooks.count == 2)
    }
    @Test func failedPublicationDoesNotConsumeTheWeek() async throws {
        let repository = FantasyTestRepository()
        let manager = try await prepared(repository)
        let story = try await manager.createStory(memory: "A dance")
        await repository.setFailure()
        await #expect(throws: AppFailure.self) { _ = try await manager.publish(story) }
        #expect(manager.publishedBooks.isEmpty)
        #expect(manager.nextPublicationDate == nil)
    }
    @Test func publishedBookRemainsAlongsideActiveCatalogueDuringSyncAndCanBeRead() async throws {
        let fantasy = try await prepared(FantasyTestRepository())
        let story = try await fantasy.createStory(memory: "A dance")
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: PersonalLibraryCatalogue(), purchases: purchases, progress: progress, personalLibrary: fantasy)
        try await progress.load()
        try await library.load()
        let book = try await fantasy.publish(story)
        #expect(await library.discover(level: nil, format: nil).first?.id == book.id)
        await library.sync()
        #expect(Set(library.books.map(\.id)) == [book.id, "original"])
        #expect(await library.books(by: book.storyteller).map(\.id) == [book.id])
        #expect(await library.authors.contains { $0.id == book.authorID })
        let learning = LearningManager(purchases: purchases, progress: progress)
        #expect(learning.canRead(book))
        for index in book.sentences.indices { _ = try await learning.advance(book: book, from: index) }
        _ = try await learning.finishReading(book)
        #expect(progress.snapshot.completed.contains(book.id))
    }
    @Test func earlierArchiveDecodesWithoutPublications() throws {
        let archive = try JSONDecoder().decode(FantasyArchive.self, from: Data("{\"stories\":[]}".utf8))
        #expect(archive.publications == nil)
    }
}
