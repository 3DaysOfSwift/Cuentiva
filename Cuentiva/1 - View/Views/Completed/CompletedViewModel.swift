import Foundation
import Observation
@MainActor @Observable final class CompletedViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    var streak: Int { progress.streak }
    var week: [WeekDay] { progress.week }
    var query = ""
    var format: BookFormat?
    var sort: BookSort = .library
    var selectedBook: Book?
    private(set) var presentation = LibraryPresentation()
    var books: [Book] { presentation.books }
    var total: Int { presentation.completedTotal }
    var practiceDays: Int { presentation.practiceDays }
    var doubloons: Int { presentation.doubloons }
    var refreshID: LibraryRequest {
        .init(revision: library.revision, query: .init(text: query, completedOnly: true, format: format, sort: sort))
    }
    func refresh() async {
        let requested = refreshID
        let result = await library.presentation(requested.query)
        guard !Task.isCancelled, requested == refreshID else { return }
        presentation = result
    }
    init(library: any LibraryFeature = AppModel.shared.library,
         progress: any ProgressFeature = AppModel.shared.progress) {
        self.library = library
        self.progress = progress
    }
}
