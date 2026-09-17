import Foundation
import Observation
@MainActor @Observable final class HomeViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    var selectedBook: Book?
    var query = ""
    var format: BookFormat?
    var sort: BookSort = .library
    var level = "All"
    var hideCompleted = false
    var books: [Book] { library.search(query, level: level == "All" ? nil : level, completedOnly: false, format: format, sort: sort, hideCompleted: hideCompleted) }
    var total: Int { progress.snapshot.completed.count }
    var streak: Int { progress.streak }
    var week: [WeekDay] { progress.week }
    func completed(_ book: Book) -> Bool { progress.snapshot.completed.contains(book.id) }
    func coverage(_ book: Book) -> String { library.coverage(book) }
    init(library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress) { self.library = library; self.progress = progress }
}
