import Foundation
import Observation
@MainActor @Observable final class CompletedViewModel {
    private let library: any LibraryFeature
    var query = ""
    var format: BookFormat?
    var sort: BookSort = .library
    var selectedBook: Book?
    var books: [Book] { library.search(query, level: nil, completedOnly: true, format: format, sort: sort) }
    init(library: any LibraryFeature = AppModel.shared.library) { self.library = library }
}
