import Foundation
import Observation

@MainActor @Observable final class AuthorViewModel {
    let author: Author
    private let library: any LibraryFeature
    var chatUnlocked: Bool { progress.snapshot.chatUnlocked }
    private let progress: any ProgressFeature
    var selectedBook: Book?
    private(set) var books: [Book] = []
    var refreshID: LibraryRequest { .init(revision: library.revision, query: .init(authorID: author.id)) }
    func refresh() async {
        let requested = refreshID
        let result = await library.matchingBooks(requested.query)
        guard !Task.isCancelled, requested == refreshID else { return }
        books = result
    }
    func completed(_ book: Book) -> Bool { progress.snapshot.completed.contains(book.id) }
    init(author: Author, library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress) {
        self.author = author; self.library = library; self.progress = progress
    }
}
