//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class BookstoreViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    var query = ""
    var level = "All"
    var format: BookFormat?
    var sort: BookSort = .library
    var hideCompleted = true
    var selectedBook: Book?
    private(set) var presentation = LibraryPresentation()
    var books: [Book] { presentation.books }
    var refreshID: LibraryRequest {
        .init(revision: library.revision, query: .init(text: query, level: level == "All" ? nil : level,
            format: format, sort: sort, hideCompleted: hideCompleted))
    }
    init(library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress) {
        self.library = library; self.progress = progress
    }
    func refresh() async {
        let request = refreshID
        let result = await library.presentation(request.query)
        guard !Task.isCancelled, request == refreshID else { return }
        presentation = result
    }
    func completed(_ book: Book) -> Bool { progress.snapshot.completed.contains(book.id) }
    func coverage(_ book: Book) -> String { presentation.coverage[book.id] ?? "" }
}
