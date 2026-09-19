import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct LibraryPresentationTests {
    @Test func homeAndCollectionReflectCommittedCompletion() async throws {
        let (p,s,l,_,_) = try await makeViewModelTestGraph(); p.hasAccess = true
        let home = HomeViewModel(library: l, progress: s), collection = CompletedViewModel(library: l)
        await home.refresh(); await collection.refresh()
        #expect(home.books.count == 1); #expect(collection.books.isEmpty)
        #expect(home.hideCompleted)
        #expect(home.nextRead?.id == "cafe")
        home.query = "cafe"; home.level = "A1"; home.format = .story; home.sort = .title
        await home.refresh()
        #expect(home.books.count == 1)
        let book = sample(); try await s.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await s.complete(book: book)
        await home.refresh(); await collection.refresh()
        #expect(home.total == 1); #expect(collection.books.count == 1)
        #expect(home.books.isEmpty)
        #expect(home.nextRead?.id == "cafe")
        #expect(home.revisiting)
        home.hideCompleted = false
        await home.refresh()
        #expect(home.books.count == 1)
        home.level = "B1"
        await home.refresh()
        #expect(home.books.isEmpty)
    }
}
