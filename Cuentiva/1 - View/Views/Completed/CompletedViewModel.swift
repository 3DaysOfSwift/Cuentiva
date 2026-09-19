import Foundation
import Observation
@MainActor @Observable final class CompletedViewModel {
    private let library: any LibraryFeature
    var query = ""
    var format: BookFormat?
    var sort: BookSort = .library
    var selectedBook: Book?
    private(set) var books: [Book] = []
    var refreshID: LibraryRequest {
        .init(input: library.input, query: .init(text: query, completedOnly: true, format: format, sort: sort))
    }
    func refresh() async {
        let requested = refreshID
        let result = await library.presentation(requested.query)
        guard !Task.isCancelled, requested == refreshID else { return }
        books = result.books
    }
    init(library: any LibraryFeature = AppModel.shared.library) { self.library = library }
}
