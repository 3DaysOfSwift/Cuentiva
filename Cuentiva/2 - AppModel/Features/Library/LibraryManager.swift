import Foundation
import Observation

@MainActor protocol LibraryFeature: AnyObject, Sendable {
    var books: [Book] { get }
    var introduction: Book? { get }
    func load() async throws
    func search(_ query: String, level: String?, completedOnly: Bool) -> [Book]
    func coverage(_ book: Book) -> String
}
@MainActor @Observable final class LibraryManager: LibraryFeature {
    private(set) var books: [Book] = []
    private let repository: any BookRepository
    private let purchases: any PurchaseFeature
    private let progress: any ProgressFeature
    init(repository: any BookRepository, purchases: any PurchaseFeature, progress: any ProgressFeature) {
        self.repository = repository; self.purchases = purchases; self.progress = progress
    }
    var introduction: Book? { books.first { $0.id == "cafe" } }
    func load() async throws { if books.isEmpty { books = try await repository.books() } }
    func search(_ query: String, level: String?, completedOnly: Bool) -> [Book] {
        guard purchases.hasAccess else { return [] }
        return books.filter { book in
            (query.isEmpty || "\(book.title) \(book.englishTitle) \(book.author)".localizedStandardContains(query)) &&
            (level == nil || book.level == level) && (!completedOnly || progress.snapshot.completed.contains(book.id))
        }
    }
    func coverage(_ book: Book) -> String {
        let lemmas = Set(book.vocabulary.map(\.lemma))
        let known = lemmas.filter { progress.snapshot.vocabulary[$0] == .known }.count
        return "\(known) of \(lemmas.count) words known"
    }
}
