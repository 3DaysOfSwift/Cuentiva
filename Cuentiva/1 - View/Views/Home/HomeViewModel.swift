import Foundation
import Observation

@MainActor @Observable final class HomeViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    var practiceBook: Book?
    var challengeDay: String?
    var dailyChallenge: DailyMatchChallenge? { progress.dailyChallenge }
    var challengeBooks: [Book] { dailyReads.filter { dailyChallenge?.bookIDs.contains($0.id) == true } }
    func playDailyGame(_ book: Book) {
        guard let challenge = dailyChallenge, challenge.bookIDs.contains(book.id) else { return }
        challengeDay = challenge.day; practiceBook = book
    }
    var selectedBook: Book? {
        didSet {
            guard let selectedBook else { return }
            readingVisit = (selectedBook.id, completed(selectedBook), dailyReads.contains { $0.id == selectedBook.id })
        }
    }
    private var readingVisit: (id: String, wasCompleted: Bool, wasDailyRead: Bool)?
    private(set) var readCelebration = 0
    var focusedBookID: String?
    var dailyReadingError: String?
    private(set) var preparingDailyReads = false
    private(set) var presentation = LibraryPresentation()
    var refreshID: LibraryRequest { .init(revision: library.revision, query: libraryQuery) }
    private var libraryQuery: LibraryQuery {
        .init(text: query, level: level == "All" ? nil : level, format: format, sort: sort,
            hideCompleted: hideCompleted, recommendations: query.isEmpty && sort == .library && hideCompleted)
    }
    @discardableResult
    func refresh() async -> Bool {
        let requested = refreshID
        let result = await library.presentation(requested.query)
        guard !Task.isCancelled, requested == refreshID else { return false }
        presentation = result
        // Publish an explicit selection with the prepared books, before Today mounts.
        // The visible fallback alone cannot position a newly created scroll view.
        if !dailyReads.contains(where: { $0.id == focusedBookID }) {
            focusNextRead()
        }
        return true
    }
    var dailyReadsCompleted: Bool { presentation.dailyReadsCompleted }
    var showTomorrowFooter: Bool { dailyReads.count == 3 && dailyReadsCompleted }
    private(set) var dailyReadingNotice: String?
    var query = ""
    var format: BookFormat?
    var sort: BookSort = .library
    var level = "All"
    var hideCompleted = true
    var formatShowcase: [Book] { presentation.formatShowcase }
    var authors: [Author] { presentation.authors }
    var dailyReads: [Book] { presentation.dailyReads }
    var revisiting: Bool { presentation.revisiting }
    var nextRead: Book? { presentation.nextRead }
    var focusedRead: Book? { dailyReads.first { $0.id == focusedBookID } ?? nextRead }
    var readButtonTitle: String {
        if preparingDailyReads { return "Loading books…" }
        if dailyReadsCompleted { return "Load 3 more books" }
        return "Read book"
    }

    func performReadingAction() async {
        if dailyReadsCompleted { await loadMoreBooks() }
        else { selectedBook = focusedRead }
    }
    func retryDailyReads() async {
        if dailyReadsCompleted { await loadMoreBooks() }
        else { await prepareDailyReads() }
    }
    private func loadMoreBooks() async {
        guard !preparingDailyReads else { return }
        preparingDailyReads = true
        dailyReadingError = nil
        dailyReadingNotice = nil
        defer { preparingDailyReads = false }
        do {
            try await library.loadMoreDailyReads()
            await refresh()
            focusNextRead()
            if dailyReads.count < 3 {
                dailyReadingNotice = dailyReads.count == 1
                    ? "One unread book remains. Enjoy your next story."
                    : "Two unread books remain. Enjoy your next stories."
            }
        } catch { dailyReadingError = error.localizedDescription }
    }
    func readingDismissed() async {
        let visit = readingVisit
        readingVisit = nil
        await refresh()
        focusNextRead()
        guard let visit, visit.wasDailyRead, !visit.wasCompleted,
              progress.snapshot.completed.contains(visit.id),
              let next = focusedRead, next.id != visit.id, !completed(next) else { return }
        readCelebration += 1
    }

    func tapDailyRead(_ book: Book) {
        guard dailyReads.contains(where: { $0.id == book.id }) else { return }
        if focusedRead?.id == book.id { selectedBook = book }
        else { focusedBookID = book.id }
    }

    func focusNextRead() { focusedBookID = nextRead?.id }
    func prepareDailyReads() async {
        guard !preparingDailyReads else { return }
        preparingDailyReads = true
        defer { preparingDailyReads = false }
        do {
            try await library.prepareDailyReads()
            dailyReadingError = nil
            await refresh()
            focusNextRead()
        } catch {
            dailyReadingError = "Couldn’t save today’s selection. Please try again."
        }
    }
    func hasStarted(_ book: Book) -> Bool {
        !progress.snapshot.attempts[book.id, default: []].isEmpty
            || progress.snapshot.positions[book.id, default: 0] > 0
    }
    var furtherRecommendations: [Book] { presentation.moreBooks.filter { book in !dailyReads.contains { $0.id == book.id } } }
    var books: [Book] { presentation.books }
    var total: Int { progress.snapshot.completed.count }
    var streak: Int { progress.streak }
    var week: [WeekDay] { progress.week }
    func completed(_ book: Book) -> Bool { progress.snapshot.completed.contains(book.id) }
    func coverage(_ book: Book) -> String { presentation.coverage[book.id] ?? "" }
    init(
        library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress
    ) {
        self.library = library
        self.progress = progress
    }
}
