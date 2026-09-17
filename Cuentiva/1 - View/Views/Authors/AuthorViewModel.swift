import Foundation
import Observation

@MainActor @Observable final class AuthorViewModel {
    let author: Author
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    var selectedBook: Book?
    var books: [Book] { library.books(by: author) }
    func completed(_ book: Book) -> Bool { progress.snapshot.completed.contains(book.id) }
    init(author: Author, library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress) {
        self.author = author; self.library = library; self.progress = progress
    }
}
