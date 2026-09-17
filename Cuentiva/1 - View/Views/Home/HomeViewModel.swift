import Foundation
import Observation
@MainActor @Observable final class HomeViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    var selectedBook: Book?
    var focusedBookID: String?
    var dailyReadingError: String?
    private var preparingDailyReads = false
    var query = ""
    var format: BookFormat?
    var sort: BookSort = .library
    var level = "All"
    var hideCompleted = true
    var authors: [Author] { library.authors }
    var dailyReads: [Book] { library.dailyReads }
    var revisiting: Bool { library.revisiting }
    var nextRead: Book? { library.nextRead }
    var focusedRead: Book? { dailyReads.first { $0.id == focusedBookID } ?? nextRead }
    var readButtonTitle: String {
        guard let book = focusedRead, let index = dailyReads.firstIndex(where: { $0.id == book.id }) else { return "Read book" }
        return "Read book \(index + 1)"
    }
    func focusNextRead() { focusedBookID = nextRead?.id }
    func prepareDailyReads() async {
        guard !preparingDailyReads else { return }
        preparingDailyReads = true
        defer { preparingDailyReads = false }
        do {
            try await library.prepareDailyReads()
            dailyReadingError = nil
            focusNextRead()
        } catch {
            dailyReadingError = "Couldn’t save today’s selection. Please try again."
        }
    }
    func hasStarted(_ book: Book) -> Bool { !progress.snapshot.attempts[book.id, default: []].isEmpty || progress.snapshot.positions[book.id, default: 0] > 0 }
    var books: [Book] {
        if query.isEmpty && sort == .library && hideCompleted { return library.discover(level: level == "All" ? nil : level, format: format) }
        return library.search(query, level: level == "All" ? nil : level, completedOnly: false, format: format, sort: sort, hideCompleted: hideCompleted) }
    var total: Int { progress.snapshot.completed.count }
    var streak: Int { progress.streak }
    var week: [WeekDay] { progress.week }
    func completed(_ book: Book) -> Bool { progress.snapshot.completed.contains(book.id) }
    func coverage(_ book: Book) -> String { library.coverage(book) }
    init(library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress) { self.library = library; self.progress = progress }
}
