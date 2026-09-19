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

/// A small invalidation key. Views never compare catalogue or progress payloads.
struct LibraryRevision: Sendable, Equatable {
    var catalogue = UUID()
    var personal: UUID?
    var progress = UUID()
    var hasAccess = false
    var checkingAccess = false
    var day = Date.distantPast
}

private struct LibraryInput: Sendable {
    var introduction: Book? = nil
    let catalogue: [Book]
    let personal: PersonalLibraryContent
    let authors: [Author]
    let arrivals: [String: Date]
    let progress: LearnerProgress
    let hasAccess: Bool
    let day: Date
    let calendar: Calendar
}

struct LibraryRequest: Equatable {
    let revision: LibraryRevision
    let query: LibraryQuery
}

struct LibraryPresentation: Sendable {
    var formatCounts: [BookFormat: Int] = [:]
    var completedTotal = 0
    var practiceDays = 0
    var doubloons = 0
    var books: [Book] = []
    var dailyReads: [Book] = []
    var nextRead: Book?
    var dailyReadsCompleted = false
    var revisiting = false
    var authors: [Author] = []
    var coverage: [String: String] = [:]
    var formatShowcase: [Book] = []
    var moreBooks: [Book] = []
}

@MainActor protocol LibraryFeature: AnyObject, Sendable {
    var books: [Book] { get }
    var introduction: Book? { get }
    var revision: LibraryRevision { get }
    func matchingBooks(_ query: LibraryQuery) async -> [Book]
    func presentation(_ query: LibraryQuery) async -> LibraryPresentation
    func load() async throws
    func loadIntroduction() async throws
    func sync() async
    var syncing: Bool { get }
    var syncMessage: String? { get }
    func prepareDailyReads() async throws
    func loadMoreDailyReads() async throws
}

extension LibraryFeature {
    func loadIntroduction() async throws { try await load() }
}

@MainActor @Observable final class LibraryManager: LibraryFeature {
    private var catalogueBooks: [Book] = []
    private var catalogueRevision = UUID()
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
        guard purchases.hasAccess, !purchases.checking else { return [] }
        let personal = personalLibrary?.publishedBooks ?? []
        let ids = Set(personal.map(\.id))
        return personal + catalogueBooks.filter { !ids.contains($0.id) }
    }
    private var introductoryBook: Book?
    var introduction: Book? { introductoryBook ?? catalogueBooks.first { $0.id == "cafe" } }
    var revision: LibraryRevision {
        .init(catalogue: catalogueRevision, personal: personalLibrary?.libraryRevision,
            progress: progress.revision, hasAccess: purchases.hasAccess, checkingAccess: purchases.checking,
            day: calendar.startOfDay(for: now()))
    }
    private var input: LibraryInput {
        LibraryInput(introduction: introduction, catalogue: catalogueBooks, personal: personalLibrary?.libraryContent ?? .init(),
            authors: authorProfiles, arrivals: catalogueArrivals, progress: progress.snapshot,
            hasAccess: purchases.hasAccess && !purchases.checking,
            day: calendar.startOfDay(for: now()), calendar: calendar)
    }
    init(repository: any BookRepository, purchases: any PurchaseFeature, progress: any ProgressFeature,
         personalLibrary: (any PersonalLibraryFeature)? = nil,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.repository = repository; self.purchases = purchases; self.progress = progress
        self.personalLibrary = personalLibrary; self.now = now; self.calendar = calendar
    }
    func presentation(_ query: LibraryQuery = .init()) async -> LibraryPresentation {
        await worker.prepare(input, revision: revision, query: query)
    }
    func matchingBooks(_ query: LibraryQuery) async -> [Book] {
        await worker.matchingBooks(input, revision: revision, query: query)
    }
    var recommendationBuildCount: Int { get async { await worker.recommendationBuildCount } }
    var discoveryBuildCount: Int { get async { await worker.discoveryBuildCount } }
    func loadIntroduction() async throws {
        guard introductoryBook == nil else { return }
        introductoryBook = try await repository.introduction()
        catalogueRevision = UUID()
    }
    func load() async throws {
        guard purchases.hasAccess, !purchases.checking else { throw AppFailure.locked }
        if catalogueBooks.isEmpty {
            let loaded = try await repository.books()
            let arrivals = await repository.arrivals()
            let authors = await repository.authors().map(\.storyteller)
            try Task.checkCancellation()
            guard purchases.hasAccess, !purchases.checking else { throw AppFailure.locked }
            catalogueArrivals = arrivals
            catalogueBooks = loaded
            authorProfiles = authors
            catalogueRevision = UUID()
        }
    }
    func sync() async {
        guard purchases.hasAccess, !purchases.checking, !syncing, let repository = repository as? any SyncingBookRepository else { return }
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
        await matchingBooks(.init(text: query, level: level, completedOnly: completedOnly,
            format: format, sort: sort, hideCompleted: hideCompleted))
    }
    func discover(level: String?, format: BookFormat?) async -> [Book] {
        await presentation(.init(level: level, format: format, recommendations: true)).books
    }
    func books(by author: Author) async -> [Book] {
        await matchingBooks(.init(authorID: author.id))
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
    private var input = LibraryInput(catalogue: [], personal: .init(), authors: [], arrivals: [:],
        progress: .init(), hasAccess: false, day: .distantPast, calendar: .current)
    private var revision: LibraryRevision?
    private var books: [Book] = []
    private var personalBooks: [Book] = []
    private var available: [Book] = []
    private var discovery: (recommendations: [Book], presentation: LibraryPresentation)?
    private var coverageByID: [String: String] = [:]
    private var recommendationOrder = LibraryRecommendationOrder()
    var recommendationBuildCount: Int { recommendationOrder.buildCount }
    private(set) var discoveryBuildCount = 0

    private func use(_ input: LibraryInput, revision: LibraryRevision) {
        guard self.revision != revision else { return }
        self.revision = revision
        self.input = input
        personalBooks = input.personal.preparedBooks()
        let personalIDs = Set(personalBooks.map(\.id))
        books = personalBooks + input.catalogue.filter { !personalIDs.contains($0.id) }
        available = input.hasAccess ? books : []
        discovery = nil
        coverageByID = [:]
    }

    func matchingBooks(_ input: LibraryInput, revision: LibraryRevision, query: LibraryQuery) -> [Book] {
        use(input, revision: revision)
        return search(query)
    }

    func prepare(_ input: LibraryInput, revision: LibraryRevision, query: LibraryQuery) -> LibraryPresentation {
        use(input, revision: revision)
        let shared = discoveryState()
        var result = shared.presentation
        var allFormats = query
        allFormats.format = nil
        let candidates = query.recommendations ? shared.recommendations.filter {
            query.level == nil || $0.level == query.level
        } : search(allFormats)
        result.formatCounts = Dictionary(grouping: candidates, by: \.kind).mapValues(\.count)
        result.books = candidates.filter { query.format == nil || $0.kind == query.format }
        result.completedTotal = input.progress.completed.count
        result.practiceDays = input.progress.practiceDays.count
        result.doubloons = input.progress.availableChatCoins
        for book in result.books where coverageByID[book.id] == nil {
            let lemmas = Set(book.vocabulary.map(\.lemma))
            let known = lemmas.filter { input.progress.vocabulary[$0] == .known }.count
            coverageByID[book.id] = "\(known) of \(lemmas.count) words known"
        }
        result.coverage = coverageByID
        return result
    }

    private func search(_ query: LibraryQuery) -> [Book] {
        // Author profiles may show the free introduction before paid content loads.
        let candidates: [Book]
        if !input.hasAccess, query.authorID != nil, let introduction = input.introduction {
            candidates = [introduction]
        } else {
            candidates = available
        }
        let matches = candidates.filter { book in
            (query.text.isEmpty || "\(book.title) \(book.englishTitle) \(book.storytellerName) \(book.cast.joined(separator: " "))"
                .localizedStandardContains(query.text))
            && (!query.hideCompleted || !input.progress.completed.contains(book.id))
            && (query.format == nil || book.kind == query.format)
            && (query.level == nil || book.level == query.level)
            && (!query.completedOnly || input.progress.completed.contains(book.id))
            && (query.authorID == nil || book.authorID == query.authorID)
        }
        switch query.sort {
        case .library: return matches
        case .title: return matches.sorted(by: titleOrder)
        case .difficulty: return matches.sorted { $0.level == $1.level ? titleOrder($0, $1) : $0.level < $1.level }
        case .type: return matches.sorted { $0.kind == $1.kind ? titleOrder($0, $1) : $0.kind.title < $1.kind.title }
        }
    }

    /// Shared Discover work is prepared once per revision, not once per filter or screen.
    private func discoveryState() -> (recommendations: [Book], presentation: LibraryPresentation) {
        if let discovery { return discovery }
        discoveryBuildCount += 1
        let eligible = available.filter(eligibleToday)
        let recycling = eligible.isEmpty
        let ordered = dailyOrder(recycling ? available : eligible, recycling: recycling)
        let selection = dailyReads(candidates: ordered)
        let finished = !selection.isEmpty && selection.allSatisfy { input.progress.completed.contains($0.id) }
        let currentIDs = Set(selection.map(\.id))
        let unread = finished ? available.filter {
            !currentIDs.contains($0.id) && !input.progress.completed.contains($0.id)
        } : []
        let personal = personalBooks.first?.personalAuthor
        let profiles = (personal.map { [$0] } ?? []) + input.authors.filter { $0.id != personal?.id }
        let visibleIDs = Set(available.compactMap(\.authorID))
        let presentation = LibraryPresentation(
            dailyReads: selection,
            nextRead: selection.first { !input.progress.completed.contains($0.id) } ?? selection.first,
            dailyReadsCompleted: finished, revisiting: !available.isEmpty && recycling,
            authors: Author.weeklyOrder(profiles.filter { visibleIDs.contains($0.id) }, on: input.day),
            formatShowcase: [BookFormat.movieScript, .verbs, .story].compactMap { format in
                available.first { $0.kind == format }
            },
            moreBooks: Array(dailyOrder(unread, recycling: false).prefix(3)))
        let result = (recommendations: ordered, presentation: presentation)
        discovery = result
        return result
    }

    private func eligibleToday(_ book: Book) -> Bool {
        guard !input.progress.completed.contains(book.id) else { return false }
        let started = input.progress.bookLastRead?[book.id] != nil
            || !input.progress.attempts[book.id, default: []].isEmpty
            || input.progress.positions[book.id, default: 0] > 0
        guard started else { return true }
        guard let date = input.progress.bookLastRead?[book.id] else { return false }
        let days = input.calendar.dateComponents([.day], from: input.calendar.startOfDay(for: date), to: input.day).day ?? 4
        return (0...3).contains(days)
    }

    private func dailyOrder(_ values: [Book], recycling: Bool) -> [Book] {
        let snapshot = input.progress
        let arrivals = (snapshot.bookArrivals ?? [:]).merging(input.arrivals) { _, prepared in prepared }
        return recommendationOrder.order(values, recycling: recycling, today: input.day, calendar: input.calendar,
            arrivals: arrivals, lastRead: snapshot.bookLastRead ?? [:], level: snapshot.selectedLearningLevel)
    }

    private func dailyReads(candidates: [Book]) -> [Book] {
        guard let date = input.progress.dailyReadingDate, input.calendar.isDate(date, inSameDayAs: input.day),
              let ids = input.progress.dailyReadingIDs else { return Array(candidates.prefix(3)) }
        let lookup = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        let retained = ids.compactMap { lookup[$0] }
        if retained.count == ids.count { return Array(retained.prefix(3)) }
        let retainedIDs = Set(retained.map(\.id))
        return Array((retained + candidates.filter { !retainedIDs.contains($0.id) }).prefix(3))
    }

    private func titleOrder(_ lhs: Book, _ rhs: Book) -> Bool {
        let comparison = lhs.englishTitle.localizedCaseInsensitiveCompare(rhs.englishTitle)
        return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
    }
}
