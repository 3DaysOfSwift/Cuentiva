//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class AuthorViewModel {
    let author: Author
    private let library: any LibraryFeature
    private let supportsChat: Bool
    var chatUnlocked: Bool { progress.snapshot.canOfferChat(onSupportedDevice: supportsChat) }
    var doubloons: Int { progress.snapshot.availableChatCoins }
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
    init(author: Author, library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress, supportsChat: Bool = AppleChatGenerator.supportsDevice) {
        self.supportsChat = supportsChat
        self.author = author; self.library = library; self.progress = progress
    }
}
