import Foundation
import Observation

@MainActor protocol LibraryFeature: AnyObject, Sendable {
    var books: [Book] { get }
    var introduction: Book? { get }
    func load() async throws
    func search(_ query: String, level: String?, completedOnly: Bool, format: BookFormat?, sort: BookSort, hideCompleted: Bool) -> [Book]
    func coverage(_ book: Book) -> String
    var nextRead: Book? { get }
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
    func search(_ query: String, level: String?, completedOnly: Bool, format: BookFormat?, sort: BookSort, hideCompleted: Bool) -> [Book] {
        guard purchases.hasAccess else { return [] }
        let matches = books.filter { book in
            (book.submissionLocation == nil || progress.snapshot.completed.contains(book.id)) &&
            (query.isEmpty || "\(book.title) \(book.englishTitle) \(book.author) \(book.cast.joined(separator: " "))".localizedStandardContains(query)) &&
            (!hideCompleted || !progress.snapshot.completed.contains(book.id)) &&
            (format == nil || book.kind == format) && (level == nil || book.level == level) && (!completedOnly || progress.snapshot.completed.contains(book.id))
        }
        switch sort {
        case .library: return matches
        case .title: return matches.sorted(by: titleOrder)
        case .difficulty: return matches.sorted { $0.level == $1.level ? titleOrder($0, $1) : $0.level < $1.level }
        case .type: return matches.sorted { $0.kind == $1.kind ? titleOrder($0, $1) : $0.kind.title < $1.kind.title }
        }
    }
    var nextRead: Book? {
        let unread = search("", level: nil, completedOnly: false, format: nil, sort: .library, hideCompleted: true)
        // Continue an unfinished book before offering a fresh one. Library order breaks ties.
        return unread.first { !progress.snapshot.attempts[$0.id, default: []].isEmpty || progress.snapshot.positions[$0.id, default: 0] > 0 }
            ?? unread.first { $0.level == progress.snapshot.selectedLearningLevel?.rawValue }
            ?? unread.first
    }
    private func titleOrder(_ lhs: Book, _ rhs: Book) -> Bool {
        let comparison = lhs.englishTitle.localizedCaseInsensitiveCompare(rhs.englishTitle)
        return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
    }
    func coverage(_ book: Book) -> String {
        let lemmas = Set(book.vocabulary.map(\.lemma))
        let known = lemmas.filter { progress.snapshot.vocabulary[$0] == .known }.count
        return "\(known) of \(lemmas.count) words known"
    }
}

extension LibraryFeature {
    func search(_ query: String, level: String?, completedOnly: Bool, format: BookFormat?, sort: BookSort) -> [Book] {
        search(query, level: level, completedOnly: completedOnly, format: format, sort: sort, hideCompleted: false)
    }
    func search(_ query: String, level: String?, completedOnly: Bool) -> [Book] {
        search(query, level: level, completedOnly: completedOnly, format: nil, sort: .library)
    }
}
