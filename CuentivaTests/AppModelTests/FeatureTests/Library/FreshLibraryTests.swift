import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@MainActor @Suite struct FreshLibraryTests {
    @Test func formatShowcaseKeepsEditorialOrderAcrossSearchFilters() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        var script = sample("script"); script.format = .movieScript
        var verbs = sample("verbs"); verbs.format = .verbs
        var story = sample("story")
        story.submissionLocation = StoryLocation(latitude: 13.75, longitude: 100.5, accuracy: 100, capturedAt: .now, placeName: "Bangkok")
        let library = LibraryManager(repository: MemoryBooks(values: [story, verbs, script]), purchases: purchases, progress: progress)
        try await progress.load()
        try await library.load()
        let all = await library.presentation(.init())
        #expect(Set(all.books.map(\.id)) == ["script", "verbs", "story"])
        #expect(all.formatShowcase.map(\.id) == ["script", "verbs", "story"])
        let filtered = await library.presentation(.init(text: "no matching story", level: "B1"))
        #expect(filtered.books.isEmpty)
        #expect(filtered.formatShowcase.map(\.id) == ["script", "verbs", "story"])
        purchases.hasAccess = false
        #expect(await library.presentation(.init()).formatShowcase.isEmpty)
    }

    @Test func formatShowcaseDoesNotInventMissingTypes() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: [sample()]), purchases: purchases, progress: progress)
        try await progress.load()
        try await library.load()
        #expect(await library.presentation(.init()).formatShowcase.map(\.kind) == [.story])
        #expect(Author.demoProfiles.filter { $0.id == Author.pipa.id }.count == 1)
        #expect(Author.pipa.portrait == "StorytellerPipa")
    }

    @Test func freeIntroductionAppearsOnlyOnItsAuthorsProfile() async throws {
        let purchases = TestPurchases()
        let progress = ProgressManager(repository: MemoryProgress())
        var book = sample("cafe"); book.authorID = Author.pipa.id
        let library = LibraryManager(repository: MemoryBooks(values: [book, sample("paid")]), purchases: purchases, progress: progress)
        try await progress.load()
        #expect(await library.books(by: .pipa).isEmpty)
        try await library.loadIntroduction()
        #expect(await library.books(by: .pipa).map(\.id) == ["cafe"])
        #expect(await library.matchingBooks(.init(authorID: "ana")).isEmpty)
        #expect(await library.matchingBooks(.init()).isEmpty)
        #expect(await library.dailyReads.isEmpty)
    }

    @Test func formatCountsRespectFiltersWhileCompletedStatsStayLifetime() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let story = sample("story")
        var verbs = sample("verbs"); verbs.format = .verbs
        let library = LibraryManager(repository: MemoryBooks(values: [story, verbs]), purchases: purchases, progress: progress)
        try await progress.load(); try await library.load()
        let filtered = await library.presentation(.init(format: .verbs))
        #expect(filtered.books.map(\.id) == ["verbs"])
        #expect(filtered.formatCounts[.verbs] == 1)
        #expect(filtered.formatCounts[.story] == 1)
        try await progress.recordEncounter(book: story, sentence: story.sentences[0])
        _ = try await progress.complete(book: story)
        let completed = await library.presentation(.init(completedOnly: true, format: .verbs))
        #expect(completed.books.isEmpty)
        #expect(completed.formatCounts[.story] == 1)
        #expect(completed.formatCounts[.verbs, default: 0] == 0)
        #expect(completed.completedTotal == 1)
        #expect(completed.practiceDays == 1)
        #expect(completed.doubloons == 1)
        let missing = await library.presentation(.init(text: "no matching words"))
        #expect(missing.formatCounts.isEmpty)
        #expect(missing.completedTotal == 1)
    }

    final class Clock { var date = Date(timeIntervalSince1970: 1_800_014_400) }
    @Test func loadingAndDisplayingLibraryNeverWritesProgress() async throws {
        let store = MemoryProgress(), purchases = TestPurchases(); purchases.hasAccess = true
        await store.setFailure(true)
        let progress = ProgressManager(repository: store)
        let library = LibraryManager(repository: MemoryBooks(values: [sample()]), purchases: purchases, progress: progress)
        try await progress.load()
        try await library.load()
        #expect(await library.dailyReads.count == 1)
        #expect(await library.discover(level: nil, format: nil).count == 1)
        #expect(await store.saveAttempts == 0)
        // A persistence failure belongs to post-display preparation, not launch.
        await #expect(throws: AppFailure.self) { try await library.prepareDailyReads() }
        #expect(library.books.count == 1)
    }
    @Test func recommendationSortIsReusedUntilDayOrReadingStateChanges() async throws {
        let clock = Clock(), purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress(), now: { clock.date })
        let library = LibraryManager(repository: MemoryBooks(values: (0..<8).map { sample("cache-\($0)") }),
            purchases: purchases, progress: progress, now: { clock.date })
        try await progress.load()
        try await library.load()
        let initial = await library.discover(level: nil, format: nil)
        for _ in 0..<10 {
            _ = await library.dailyReads; _ = await library.nextRead
            #expect(await library.discover(level: "A1", format: nil).map(\.id) == initial.map(\.id))
        }
        #expect(await library.recommendationBuildCount == 1)
        clock.date = try #require(Calendar.current.date(byAdding: .day, value: 1, to: clock.date))
        _ = await library.dailyReads
        #expect(await library.recommendationBuildCount == 2)
        let book = initial[0]
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        #expect(await !library.discover(level: nil, format: nil).contains { $0.id == book.id })
        #expect(await library.recommendationBuildCount == 3)
    }
    @Test func dailySelectionRetainsCompletedBooksAcrossRelaunchAndRenewsTomorrow() async throws {
        let clock = Clock(), store = MemoryProgress(), purchases = TestPurchases()
        purchases.hasAccess = true
        let progress = ProgressManager(repository: store, now: { clock.date })
        let books = (0..<6).map { sample("daily-\($0)") }
        let source = MemoryBooks(values: books)
        let library = LibraryManager(repository: source, purchases: purchases, progress: progress, now: { clock.date })
        try await progress.load()
        try await library.load()
        try await library.prepareDailyReads()
        let original = await library.dailyReads
        for book in original {
            try await progress.recordEncounter(book: book, sentence: book.sentences[0])
            _ = try await progress.complete(book: book)
            #expect(await library.dailyReads.map(\.id) == original.map(\.id))
            #expect(await library.nextRead?.id == (original.first { !progress.snapshot.completed.contains($0.id) } ?? original[0]).id)
        }
        let reloadedProgress = ProgressManager(repository: store, now: { clock.date })
        let reloaded = LibraryManager(repository: source, purchases: purchases, progress: reloadedProgress, now: { clock.date })
        try await reloadedProgress.load()
        try await reloaded.load(); try await reloaded.prepareDailyReads()
        #expect(await reloaded.dailyReads.map(\.id) == original.map(\.id))
        clock.date = try #require(Calendar.current.date(byAdding: .day, value: 1, to: clock.date))
        try await reloaded.prepareDailyReads()
        #expect(Set(await reloaded.dailyReads.map(\.id)).isDisjoint(with: Set(original.map(\.id))))
        #expect(reloadedProgress.snapshot.completed.count == 3)
    }
    @Test func newArrivalsLeadAndOldAttemptsRestWithoutLosingProgress() async throws {
        let clock = Clock(), store = MemoryProgress(), purchases = TestPurchases(); purchases.hasAccess = true
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let progress = ProgressManager(repository: store, now: { clock.date }, calendar: calendar)
        let old = sample("old"), ongoing = sample("ongoing"), fresh = sample("fresh")
        let first = LibraryManager(repository: MemoryBooks(values: [old, ongoing]), purchases: purchases, progress: progress, now: { clock.date }, calendar: calendar)
        try await progress.load()
        try await first.load()
        try await first.prepareDailyReads()
        try await progress.recordEncounter(book: old, sentence: old.sentences[0])
        let arrival = progress.snapshot.bookArrivals?[old.id]
        clock.date = try #require(calendar.date(byAdding: .day, value: 40, to: clock.date))
        try await progress.recordEncounter(book: ongoing, sentence: ongoing.sentences[0])
        let updated = LibraryManager(repository: MemoryBooks(values: [old, ongoing, fresh]), purchases: purchases, progress: progress, now: { clock.date }, calendar: calendar)
        try await updated.load()
        try await updated.prepareDailyReads()
        #expect(await updated.nextRead?.id == fresh.id)
        #expect(await updated.dailyReads.map(\.id).contains(ongoing.id))
        #expect(await !updated.dailyReads.map(\.id).contains(old.id))
        #expect(await updated.search("", level: nil, completedOnly: false).count == 3)
        #expect(progress.snapshot.bookArrivals?[old.id] == arrival)
        clock.date = try #require(calendar.date(byAdding: .day, value: 3, to: clock.date))
        #expect(await updated.dailyReads.map(\.id).contains(ongoing.id))
        clock.date = try #require(calendar.date(byAdding: .day, value: 1, to: clock.date))
        #expect(await !updated.dailyReads.map(\.id).contains(ongoing.id))
        #expect(!progress.snapshot.attempts[old.id, default: []].isEmpty)
        let reloaded = ProgressManager(repository: store); try await reloaded.load()
        #expect(reloaded.snapshot.bookArrivals == progress.snapshot.bookArrivals)
        #expect(reloaded.snapshot.bookLastRead == progress.snapshot.bookLastRead)
    }
    @Test func dailyThreeAreStableThenRotateWithoutNewDownloads() async throws {
        let clock = Clock(), purchases = TestPurchases(); purchases.hasAccess = true
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let progress = ProgressManager(repository: MemoryProgress(), now: { clock.date }, calendar: calendar)
        let books = (0..<6).map { sample("book-\($0)") }
        let library = LibraryManager(repository: MemoryBooks(values: books), purchases: purchases, progress: progress, now: { clock.date }, calendar: calendar)
        try await progress.load()
        try await library.load()
        clock.date = try #require(calendar.date(byAdding: .year, value: 1, to: clock.date))
        let today = Set(await library.dailyReads.map(\.id))
        #expect(today.count == 3)
        #expect(today == Set(await library.dailyReads.map(\.id)))
        clock.date = try #require(calendar.date(byAdding: .day, value: 1, to: clock.date))
        #expect(today.isDisjoint(with: Set(await library.dailyReads.map(\.id))))
        #expect(await !library.revisiting)
    }
    @Test func restingExhaustionRecyclesWithoutResettingAnything() async throws {
        let clock = Clock(), purchases = TestPurchases(); purchases.hasAccess = true
        let store = MemoryProgress(), progress = ProgressManager(repository: store, now: { clock.date })
        let book = sample()
        let library = LibraryManager(repository: MemoryBooks(values: [book]), purchases: purchases, progress: progress, now: { clock.date })
        try await progress.load()
        try await library.load(); try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        try await progress.setVocabulary("café", state: .known)
        let before = try JSONEncoder().encode(progress.snapshot)
        #expect(await library.revisiting)
        #expect(await library.dailyReads.map(\.id) == [book.id])
        #expect(progress.snapshot.completed == [book.id])
        #expect(progress.snapshot.vocabulary["café"] == .known)
        // Viewing recommendations performs no persistence writes or reset.
        #expect(try JSONDecoder().decode(LearnerProgress.self, from: before).practiceDays == progress.snapshot.practiceDays)
        purchases.hasAccess = false; #expect(await library.dailyReads.isEmpty)
    }
}
