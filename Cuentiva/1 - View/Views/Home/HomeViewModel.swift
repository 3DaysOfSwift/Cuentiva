import Foundation
import Observation

@MainActor @Observable final class HomeViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    var selectedBook: Book?
    var focusedBookID: String?
    var dailyReadingError: String?
    private(set) var preparingDailyReads = false
    private(set) var presentation = LibraryPresentation()
    var refreshID: LibraryRequest { .init(input: library.input, query: libraryQuery) }
    private var libraryQuery: LibraryQuery {
        .init(text: query, level: level == "All" ? nil : level, format: format, sort: sort,
            hideCompleted: hideCompleted, recommendations: query.isEmpty && sort == .library && hideCompleted)
    }
    func refresh() async {
        let requested = refreshID
        let result = await library.presentation(requested.query)
        guard !Task.isCancelled, requested == refreshID else { return }
        presentation = result
    }
    var dailyReadsCompleted: Bool { presentation.dailyReadsCompleted }
    var showTomorrowFooter: Bool { dailyReads.count == 3 && dailyReadsCompleted }
    private(set) var dailyReadingNotice: String?
    var query = ""
    var format: BookFormat?
    var sort: BookSort = .library
    var level = "All"
    var hideCompleted = true
    var authors: [Author] { presentation.authors }
    var dailyReads: [Book] { presentation.dailyReads }
    var revisiting: Bool { presentation.revisiting }
    var nextRead: Book? { presentation.nextRead }
    var focusedRead: Book? { dailyReads.first { $0.id == focusedBookID } ?? nextRead }
    var readButtonTitle: String {
        if preparingDailyReads { return "Loading books…" }
        if dailyReadsCompleted { return "Load 3 more books" }
        guard let book = focusedRead else { return "Read book" }
        guard let number = progress.snapshot.nextCompletionNumber(for: book.id) else { return "Read again" }
        return "Read book \(number)"
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
