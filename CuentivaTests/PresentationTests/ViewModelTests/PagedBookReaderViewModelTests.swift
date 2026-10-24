// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct PagedBookReaderViewModelTests {
    @Test func paginationKeepsEveryTranslationInOrderAndDoesNotAwardReading() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let model = PagedBookReaderViewModel(learning: LearningManager(purchases: purchases, progress: progress))
        var book = sample()
        book.continuation = (0..<20).map {
            Sentence(id: "pair-\($0)", spanish: "Ayer fui al mercado y compré un poco de pan para mi familia.",
                     english: "Yesterday I went to the market and bought some bread for my family.")
        }
        let size = CGSize(width: 390, height: 600)
        model.layout(book: book, size: size, scale: 1)
        #expect(model.pages.count > 1)
        let passages = model.pages.flatMap(\.passages)
        #expect(passages.map(\.id) == book.fullText.map(\.id))
        #expect(passages.map(\.spanish) == book.fullText.map(\.spanish))
        #expect(passages.map(\.english) == book.fullText.map(\.english))
        #expect(progress.snapshot.completed.isEmpty)
        #expect(progress.snapshot.positions.isEmpty)
        model.move(-1)
        #expect(model.page == 0)
        model.move(1000)
        #expect(model.page == model.pages.count - 1)
    }

    @Test func togglingEnglishKeepsTheCurrentPassageOnScreen() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let model = PagedBookReaderViewModel(learning: LearningManager(purchases: purchases, progress: progress))
        var book = sample()
        book.continuation = (0..<30).map {
            Sentence(id: "pair-\($0)", spanish: "Me gusta leer un buen libro por la mañana.", english: "I enjoy reading a good book in the morning.")
        }
        let size = CGSize(width: 390, height: 600)
        model.layout(book: book, size: size, scale: 1)
        let originalCount = model.pages.count
        model.move(2)
        let anchor = try #require(model.pages[model.page].passages.first?.id)
        model.showsEnglish = false
        model.layout(book: book, size: size, scale: 1)
        #expect(model.pages.count < originalCount)
        #expect(model.pages[model.page].passages.contains { $0.id == anchor })
    }

    @Test func lockedBookDoesNotExposeAnyPages() async throws {
        let purchases = TestPurchases()
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let book = sample("locked-book")
        let model = PagedBookReaderViewModel(learning: LearningManager(purchases: purchases, progress: progress))
        model.layout(book: book, size: CGSize(width: 390, height: 600), scale: 1)
        #expect(model.pages.isEmpty)
        #expect(model.error != nil)
    }
}
