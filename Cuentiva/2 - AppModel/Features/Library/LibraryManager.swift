import Foundation
import Observation

@MainActor protocol LibraryFeature: AnyObject, Sendable {
    var books: [Book] { get }
    var introduction: Book? { get }
    func load() async throws
    func sync() async
    var syncing: Bool { get }
    var syncMessage: String? { get }
    func search(
        _ query: String, level: String?, completedOnly: Bool, format: BookFormat?, sort: BookSort, hideCompleted: Bool
    ) -> [Book]
    func coverage(_ book: Book) -> String
    var nextRead: Book? { get }
    var dailyReads: [Book] { get }
    func prepareDailyReads() async throws
    var dailyReadsCompleted: Bool { get }
    func loadMoreDailyReads() async throws
    var revisiting: Bool { get }
    func discover(level: String?, format: BookFormat?) -> [Book]
    var authors: [Author] { get }
    func books(by author: Author) -> [Book]
}
@MainActor @Observable final class LibraryManager: LibraryFeature {
    private var catalogueBooks: [Book] = []
    private var catalogueArrivals: [String: Date] = [:]
    private var preparingDaily = false
    private let personalLibrary: (any PersonalLibraryFeature)?
    var books: [Book] {
        let personal = personalLibrary?.publishedBooks ?? []
        let ids = Set(personal.map(\.id))
        return personal + catalogueBooks.filter { !ids.contains($0.id) }
    }
    private var authorProfiles: [Author] = Author.demoProfiles
    private(set) var syncing = false
    private(set) var syncMessage: String?
    private let repository: any BookRepository
    private let purchases: any PurchaseFeature
    private let progress: any ProgressFeature
    private let now: () -> Date
    private let calendar: Calendar
    init(
        repository: any BookRepository, purchases: any PurchaseFeature, progress: any ProgressFeature,
        personalLibrary: (any PersonalLibraryFeature)? = nil, now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.personalLibrary = personalLibrary
        self.repository = repository
        self.purchases = purchases
        self.progress = progress
        self.now = now
        self.calendar = calendar
    }
    var introduction: Book? { books.first { $0.id == "cafe" } }
    func load() async throws {
        if catalogueBooks.isEmpty {
            async let catalogue = repository.books()
            try await progress.load()
            let loaded = try await catalogue
            catalogueArrivals = await repository.arrivals()
            catalogueBooks = loaded
            authorProfiles = await repository.authors().map(\.storyteller)
        }
    }
    func sync() async {
        guard !syncing, let repository = repository as? any SyncingBookRepository else { return }
        syncing = true
        defer { syncing = false }
        do {
            _ = try await repository.sync()
            syncMessage = "Library checked. Any new books are prepared for your next launch."
        } catch {
            syncMessage =
                "Couldn’t update the library. Your current books are still available. Try again when you’re connected."
        }
    }
    func search(
        _ query: String, level: String?, completedOnly: Bool, format: BookFormat?, sort: BookSort, hideCompleted: Bool
    ) -> [Book] {
        // Catalogue metadata may render during verification; lesson access
        // remains enforced independently by LearningManager.
        guard purchases.hasAccess || purchases.checking else { return [] }
        let matches = books.filter { book in
            (book.submissionLocation == nil || progress.snapshot.completed.contains(book.id))
                && (query.isEmpty
                    || "\(book.title) \(book.englishTitle) \(book.storytellerName) \(book.cast.joined(separator: " "))"
                        .localizedStandardContains(query))
                && (!hideCompleted || !progress.snapshot.completed.contains(book.id))
                && (format == nil || book.kind == format) && (level == nil || book.level == level)
                && (!completedOnly || progress.snapshot.completed.contains(book.id))
        }
        switch sort {
        case .library: return matches
        case .title: return matches.sorted(by: titleOrder)
        case .difficulty: return matches.sorted { $0.level == $1.level ? titleOrder($0, $1) : $0.level < $1.level }
        case .type: return matches.sorted { $0.kind == $1.kind ? titleOrder($0, $1) : $0.kind.title < $1.kind.title }
        }
    }
    private func recent(_ book: Book) -> Bool {
        guard let date = progress.snapshot.bookLastRead?[book.id] else { return false }
        let days =
            calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now()))
            .day ?? 4
        return (0...3).contains(days)
    }
    private func eligibleToday(_ book: Book) -> Bool {
        guard !progress.snapshot.completed.contains(book.id) else { return false }
        let started =
            progress.snapshot.bookLastRead?[book.id] != nil || !progress.snapshot.attempts[book.id, default: []].isEmpty
            || progress.snapshot.positions[book.id, default: 0] > 0
        return !started || recent(book)
    }
    private var available: [Book] {
        search("", level: nil, completedOnly: false, format: nil, sort: .library, hideCompleted: false)
    }
    var revisiting: Bool { !available.isEmpty && !available.contains(where: eligibleToday) }
    func discover(level: String?, format: BookFormat?) -> [Book] {
        let all = available
        let eligible = all.filter(eligibleToday)
        // Recycle recommendations only. Never reset permanent learner data.
        let pool = eligible.isEmpty ? all : eligible
        return dailyOrder(pool, recycling: eligible.isEmpty).filter {
            (level == nil || $0.level == level) && (format == nil || $0.kind == format)
        }
    }
    @ObservationIgnored private var recommendationOrder = LibraryRecommendationOrder()
    var recommendationBuildCount: Int { recommendationOrder.buildCount }

    private func dailyOrder(_ values: [Book], recycling: Bool) -> [Book] {
        let snapshot = progress.snapshot
        let arrivals = (snapshot.bookArrivals ?? [:]).merging(catalogueArrivals) { _, prepared in prepared }
        return recommendationOrder.order(
            values, recycling: recycling, today: calendar.startOfDay(for: now()), calendar: calendar,
            arrivals: arrivals, lastRead: snapshot.bookLastRead ?? [:], level: snapshot.selectedLearningLevel
        )
    }
    var dailyReads: [Book] {
        // Catalogue metadata may render during verification; lesson access
        // remains enforced independently by LearningManager.
        guard purchases.hasAccess || purchases.checking else { return [] }
        guard let date = progress.snapshot.dailyReadingDate, calendar.isDate(date, inSameDayAs: now()),
            let ids = progress.snapshot.dailyReadingIDs
        else { return Array(discover(level: nil, format: nil).prefix(3)) }
        // Retain completed cards in today's set; only replace books no longer available.
        let lookup = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        let retained = ids.compactMap { lookup[$0] }
        if retained.count == ids.count { return Array(retained.prefix(3)) }
        let candidates = discover(level: nil, format: nil)
        let retainedIDs = Set(retained.map(\.id))
        return Array((retained + candidates.filter { !retainedIDs.contains($0.id) }).prefix(3))
    }
    func prepareDailyReads() async throws {
        guard purchases.hasAccess, !books.isEmpty, !preparingDaily else { return }
        preparingDaily = true
        defer { preparingDaily = false }
        try await progress.registerLibrary(books)
        try await progress.saveDailyReading(dailyReads.map(\.id), date: calendar.startOfDay(for: now()))
    }
    var dailyReadsCompleted: Bool {
        let selection = dailyReads
        return !selection.isEmpty && selection.allSatisfy { progress.snapshot.completed.contains($0.id) }
    }
    /// Replace only a finished selection, preserving every completion and reading position.
    func loadMoreDailyReads() async throws {
        guard purchases.hasAccess else { throw AppFailure.unavailable("Unlock the library to choose more books.") }
        guard !preparingDaily else { throw AppFailure.busy }
        guard dailyReadsCompleted else { return }
        preparingDaily = true
        defer { preparingDaily = false }
        let currentIDs = Set(dailyReads.map(\.id))
        let unread = available.filter {
            !currentIDs.contains($0.id) && !progress.snapshot.completed.contains($0.id)
        }
        let next = Array(dailyOrder(unread, recycling: false).prefix(3))
        guard !next.isEmpty else {
            throw AppFailure.unavailable("You’ve read every available book. Revisit a favourite below, or check back for new stories.")
        }
        try await progress.saveDailyReading(next.map(\.id), date: calendar.startOfDay(for: now()))
    }
    var nextRead: Book? { dailyReads.first { !progress.snapshot.completed.contains($0.id) } ?? dailyReads.first }
    var authors: [Author] {
        let personal = personalLibrary?.publishedBooks.first?.personalAuthor
        let profiles = (personal.map { [$0] } ?? []) + authorProfiles.filter { $0.id != personal?.id }
        let visibleIDs = Set(available.compactMap(\.authorID))
        return Author.weeklyOrder(profiles.filter { visibleIDs.contains($0.id) }, on: now())
    }
    func books(by author: Author) -> [Book] {
        search("", level: nil, completedOnly: false, format: nil, sort: .library).filter { $0.authorID == author.id }
    }
    private func titleOrder(_ lhs: Book, _ rhs: Book) -> Bool {
        let comparison = lhs.englishTitle.localizedCaseInsensitiveCompare(rhs.englishTitle)
        return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
    }
    func coverage(_ book: Book) -> String {
        let lemmas = Set(book.vocabulary.map(\.lemma))
        let known = lemmas.filter { progress.snapshot.vocabulary[$0] == .known }.count
        return "\(known) of \(lemmas.count) words known"
    }
}

extension LibraryFeature {
    func search(_ query: String, level: String?, completedOnly: Bool, format: BookFormat?, sort: BookSort) -> [Book] {
        search(query, level: level, completedOnly: completedOnly, format: format, sort: sort, hideCompleted: false)
    }
    func search(_ query: String, level: String?, completedOnly: Bool) -> [Book] {
        search(query, level: level, completedOnly: completedOnly, format: nil, sort: .library)
    }
}
