import Foundation
import Observation

@MainActor @Observable final class AuthorViewModel {
    let author: Author
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    var selectedBook: Book?
    private(set) var books: [Book] = []
    var refreshID: LibraryRequest { .init(input: library.input, query: .init(authorID: author.id)) }
    func refresh() async {
        let requested = refreshID
        let result = await library.presentation(requested.query)
        guard !Task.isCancelled, requested == refreshID else { return }
        books = result.books
    }
    func completed(_ book: Book) -> Bool { progress.snapshot.completed.contains(book.id) }
    init(author: Author, library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress) {
        self.author = author; self.library = library; self.progress = progress
    }
}
