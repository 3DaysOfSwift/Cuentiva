// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.

import CoreText
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
        let lines = model.pages.flatMap(\.lines)
        for sentence in book.fullText {
            let rows = lines.filter { $0.sentenceID == sentence.id }
            #expect(rows.map(\.spanish).joined() == sentence.spanish)
            #expect(rows.map(\.english).joined() == sentence.english)
        }
        #expect(lines.count > book.fullText.count)
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
        let anchor = try #require(model.pages[model.page].lines.first?.sentenceID)
        model.showsEnglish = false
        model.layout(book: book, size: size, scale: 1)
        #expect(model.pages.count < originalCount)
        #expect(model.pages[model.page].lines.contains { $0.sentenceID == anchor })
    }

    @Test func longSentenceUsesSinglePhysicalLinesWithoutLosingAccentsOrWords() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let model = PagedBookReaderViewModel(learning: LearningManager(purchases: purchases, progress: progress))
        var book = sample()
        let spanish = "Colgué el letrero en mi bolsa y prometí volver el viernes."
        let english = "I hung the sign on my bag and promised to return on Friday."
        book.continuation = [Sentence(id: "long-pair", spanish: spanish, english: english)]
        model.layout(book: book, size: CGSize(width: 296, height: 300), scale: 1.5)
        let rows = model.pages.flatMap(\.lines).filter { $0.sentenceID == "long-pair" }
        #expect(rows.count > 1)
        #expect(rows.map(\.spanish).joined() == spanish)
        #expect(rows.map(\.english).joined() == english)
        for row in rows {
            for (text, font) in [(row.spanish, model.spanishFont), (row.english, model.englishFont)] {
                let value = NSAttributedString(string: text.trimmingCharacters(in: .whitespacesAndNewlines),
                    attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
                let width = CTLineGetTypographicBounds(CTLineCreateWithAttributedString(value), nil, nil, nil)
                #expect(width <= 240.5)
            }
        }
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
