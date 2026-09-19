import Foundation
import Observation

struct LibraryQuery: Sendable, Equatable {
    var text = ""
    var level: String?
    var completedOnly = false
    var format: BookFormat?
    var sort: BookSort = .library
    var hideCompleted = false
    var recommendations = false
    var authorID: String?
}

/// Value snapshot crossing the UI/worker boundary. Capturing it performs no catalogue calculations.
struct LibraryInput: Sendable, Equatable {
    let catalogue: [Book]
    let personal: [Book]
    let authors: [Author]
    let arrivals: [String: Date]
    let progress: LearnerProgress
    let hasAccess: Bool
    let day: Date
    let calendar: Calendar
}

struct LibraryRequest: Equatable {
    let input: LibraryInput
    let query: LibraryQuery
}

struct LibraryPresentation: Sendable {
    var books: [Book] = []
    var dailyReads: [Book] = []
    var nextRead: Book?
    var dailyReadsCompleted = false
    var revisiting = false
    var authors: [Author] = []
    var coverage: [String: String] = [:]
    var moreBooks: [Book] = []
}

@MainActor protocol LibraryFeature: AnyObject, Sendable {
    var books: [Book] { get }
    var introduction: Book? { get }
    var input: LibraryInput { get }
    func presentation(_ query: LibraryQuery) async -> LibraryPresentation
    func load() async throws
    func sync() async
    var syncing: Bool { get }
    var syncMessage: String? { get }
    func prepareDailyReads() async throws
    func loadMoreDailyReads() async throws
}

@MainActor @Observable final class LibraryManager: LibraryFeature {
    private var catalogueBooks: [Book] = []
    private var catalogueArrivals: [String: Date] = [:]
    private var authorProfiles: [Author] = Author.demoProfiles
    private var preparingDaily = false
    private let personalLibrary: (any PersonalLibraryFeature)?
    private let repository: any BookRepository
    private let purchases: any PurchaseFeature
    private let progress: any ProgressFeature
    private let now: () -> Date
    private let calendar: Calendar
    private let worker = LibraryWorker()
    private(set) var syncing = false
    private(set) var syncMessage: String?
    var books: [Book] {
        let personal = personalLibrary?.publishedBooks ?? []
        let ids = Set(personal.map(\.id))
        return personal + catalogueBooks.filter { !ids.contains($0.id) }
    }
    var introduction: Book? { catalogueBooks.first { $0.id == "cafe" } }
    var input: LibraryInput {
        LibraryInput(catalogue: catalogueBooks, personal: personalLibrary?.publishedBooks ?? [],
            authors: authorProfiles, arrivals: catalogueArrivals, progress: progress.snapshot,
            hasAccess: purchases.hasAccess || purchases.checking,
            day: calendar.startOfDay(for: now()), calendar: calendar)
    }
    init(repository: any BookRepository, purchases: any PurchaseFeature, progress: any ProgressFeature,
         personalLibrary: (any PersonalLibraryFeature)? = nil,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.repository = repository; self.purchases = purchases; self.progress = progress
        self.personalLibrary = personalLibrary; self.now = now; self.calendar = calendar
    }
    func presentation(_ query: LibraryQuery = .init()) async -> LibraryPresentation {
        await worker.prepare(input, query: query)
    }
    var recommendationBuildCount: Int { get async { await worker.recommendationBuildCount } }
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
    func prepareDailyReads() async throws {
        guard purchases.hasAccess, !books.isEmpty, !preparingDaily else { return }
        preparingDaily = true
        defer { preparingDaily = false }
        try await progress.registerLibrary(books)
        let selection = await presentation()
        try Task.checkCancellation()
        guard purchases.hasAccess else { return }
        try await progress.saveDailyReading(selection.dailyReads.map(\.id), date: calendar.startOfDay(for: now()))
    }
    func loadMoreDailyReads() async throws {
        guard purchases.hasAccess else { throw AppFailure.unavailable("Unlock the library to choose more books.") }
        guard !preparingDaily else { throw AppFailure.busy }
        preparingDaily = true
        defer { preparingDaily = false }
        let selection = await presentation()
        try Task.checkCancellation()
        guard purchases.hasAccess else { return }
        guard selection.dailyReadsCompleted else { return }
        guard !selection.moreBooks.isEmpty else {
            throw AppFailure.unavailable("You’ve read every available book. Revisit a favourite below, or check back for new stories.")
        }
        try await progress.saveDailyReading(selection.moreBooks.map(\.id), date: calendar.startOfDay(for: now()))
    }
}

extension LibraryFeature {
    func search(_ query: String, level: String?, completedOnly: Bool, format: BookFormat? = nil,
                sort: BookSort = .library, hideCompleted: Bool = false) async -> [Book] {
        await presentation(.init(text: query, level: level, completedOnly: completedOnly,
            format: format, sort: sort, hideCompleted: hideCompleted)).books
    }
    func discover(level: String?, format: BookFormat?) async -> [Book] {
        await presentation(.init(level: level, format: format, recommendations: true)).books
    }
    func books(by author: Author) async -> [Book] {
        await presentation(.init(authorID: author.id)).books
    }
    var dailyReads: [Book] { get async { await presentation(.init()).dailyReads } }
    var dailyReadsCompleted: Bool { get async { await presentation(.init()).dailyReadsCompleted } }
    var nextRead: Book? { get async { await presentation(.init()).nextRead } }
    var revisiting: Bool { get async { await presentation(.init()).revisiting } }
    var authors: [Author] { get async { await presentation(.init()).authors } }
}

/// All filtering, hashing, sorting, coverage and daily eligibility work runs here.
/// No suspension occurs while preparing one internally consistent result.
private actor LibraryWorker {
    private var input = LibraryInput(catalogue: [], personal: [], authors: [], arrivals: [:],
        progress: .init(), hasAccess: false, day: .distantPast, calendar: .current)
    private var books: [Book] = []
    private var previousQuery: LibraryQuery?
    private var previousPresentation: LibraryPresentation?
    func prepare(_ input: LibraryInput, query: LibraryQuery) -> LibraryPresentation {
        if input == self.input, query == previousQuery, let previousPresentation { return previousPresentation }
        self.input = input
        let personalIDs = Set(input.personal.map(\.id))
        books = input.personal + input.catalogue.filter { !personalIDs.contains($0.id) }
        let matches = query.recommendations
            ? discover(level: query.level, format: query.format)
            : search(query.text, level: query.level, completedOnly: query.completedOnly,
                format: query.format, sort: query.sort, hideCompleted: query.hideCompleted)
        let selection = dailyReads
        let finished = !selection.isEmpty && selection.allSatisfy { input.progress.completed.contains($0.id) }
        let currentIDs = Set(selection.map(\.id))
        let unread = finished ? available.filter {
            !currentIDs.contains($0.id) && !input.progress.completed.contains($0.id)
        } : []
        let result = LibraryPresentation(
            books: matches.filter { query.authorID == nil || $0.authorID == query.authorID },
            dailyReads: selection,
            nextRead: selection.first { !input.progress.completed.contains($0.id) } ?? selection.first,
            dailyReadsCompleted: finished, revisiting: revisiting, authors: authors,
            coverage: Dictionary(uniqueKeysWithValues: matches.map { ($0.id, coverage($0)) }),
            moreBooks: Array(dailyOrder(unread, recycling: false).prefix(3)))
        previousQuery = query
        previousPresentation = result
        return result
    }
    func search(
        _ query: String, level: String?, completedOnly: Bool, format: BookFormat?, sort: BookSort, hideCompleted: Bool
    ) -> [Book] {
        // Catalogue metadata may render during verification; lesson access
        // remains enforced independently by LearningManager.
        guard input.hasAccess else { return [] }
        let matches = books.filter { book in
            (book.submissionLocation == nil || input.progress.completed.contains(book.id))
                && (query.isEmpty
                    || "\(book.title) \(book.englishTitle) \(book.storytellerName) \(book.cast.joined(separator: " "))"
                        .localizedStandardContains(query))
                && (!hideCompleted || !input.progress.completed.contains(book.id))
                && (format == nil || book.kind == format) && (level == nil || book.level == level)
                && (!completedOnly || input.progress.completed.contains(book.id))
        }
        switch sort {
        case .library: return matches
        case .title: return matches.sorted(by: titleOrder)
        case .difficulty: return matches.sorted { $0.level == $1.level ? titleOrder($0, $1) : $0.level < $1.level }
        case .type: return matches.sorted { $0.kind == $1.kind ? titleOrder($0, $1) : $0.kind.title < $1.kind.title }
        }
    }
    private func recent(_ book: Book) -> Bool {
        guard let date = input.progress.bookLastRead?[book.id] else { return false }
        let days =
            input.calendar.dateComponents([.day], from: input.calendar.startOfDay(for: date), to: input.calendar.startOfDay(for: input.day))
            .day ?? 4
        return (0...3).contains(days)
    }
    private func eligibleToday(_ book: Book) -> Bool {
        guard !input.progress.completed.contains(book.id) else { return false }
        let started =
            input.progress.bookLastRead?[book.id] != nil || !input.progress.attempts[book.id, default: []].isEmpty
            || input.progress.positions[book.id, default: 0] > 0
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
    private var recommendationOrder = LibraryRecommendationOrder()
    var recommendationBuildCount: Int { recommendationOrder.buildCount }

    private func dailyOrder(_ values: [Book], recycling: Bool) -> [Book] {
        let snapshot = input.progress
        let arrivals = (snapshot.bookArrivals ?? [:]).merging(input.arrivals) { _, prepared in prepared }
        return recommendationOrder.order(
            values, recycling: recycling, today: input.calendar.startOfDay(for: input.day), calendar: input.calendar,
            arrivals: arrivals, lastRead: snapshot.bookLastRead ?? [:], level: snapshot.selectedLearningLevel
        )
    }
    var dailyReads: [Book] {
        // Catalogue metadata may render during verification; lesson access
        // remains enforced independently by LearningManager.
        guard input.hasAccess else { return [] }
        guard let date = input.progress.dailyReadingDate, input.calendar.isDate(date, inSameDayAs: input.day),
            let ids = input.progress.dailyReadingIDs
        else { return Array(discover(level: nil, format: nil).prefix(3)) }
        // Retain completed cards in today's set; only replace books no longer available.
        let lookup = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        let retained = ids.compactMap { lookup[$0] }
        if retained.count == ids.count { return Array(retained.prefix(3)) }
        let candidates = discover(level: nil, format: nil)
        let retainedIDs = Set(retained.map(\.id))
        return Array((retained + candidates.filter { !retainedIDs.contains($0.id) }).prefix(3))
    }
    var authors: [Author] {
        let personal = input.personal.first?.personalAuthor
        let profiles = (personal.map { [$0] } ?? []) + input.authors.filter { $0.id != personal?.id }
        let visibleIDs = Set(available.compactMap(\.authorID))
        return Author.weeklyOrder(profiles.filter { visibleIDs.contains($0.id) }, on: input.day)
    }
    private func titleOrder(_ lhs: Book, _ rhs: Book) -> Bool {
        let comparison = lhs.englishTitle.localizedCaseInsensitiveCompare(rhs.englishTitle)
        return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
    }
    func coverage(_ book: Book) -> String {
        let lemmas = Set(book.vocabulary.map(\.lemma))
        let known = lemmas.filter { input.progress.vocabulary[$0] == .known }.count
        return "\(known) of \(lemmas.count) words known"
    }
}
