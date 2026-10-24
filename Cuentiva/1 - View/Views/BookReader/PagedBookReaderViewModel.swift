// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.

import CoreText
import Observation
import SwiftUI
import UIKit

/// Core Text determines physical line breaks; LearningFeature owns access to the book.
@MainActor @Observable final class PagedBookReaderViewModel {
    struct Line: Identifiable {
        let sentenceID: String
        let spanishOffset: Int
        let englishOffset: Int
        let spanish: String
        let english: String
        let speaker: String?
        let startsSentence: Bool
        var id: String { "\(sentenceID):\(spanishOffset):\(englishOffset)" }
    }
    struct Page: Identifiable {
        let id: Int
        let lines: [Line]
    }
    private let learning: any LearningFeature
    private(set) var pages: [Page] = []
    private(set) var spanishFont = UIFont.systemFont(ofSize: 22)
    private(set) var englishFont = UIFont.systemFont(ofSize: 17)
    var page = 0
    var showsEnglish = true
    private(set) var controlsVisible = true
    func toggleControls() { controlsVisible.toggle() }
    var error: String?
    private var lastLayout: String?
    let rowSpacing: CGFloat = 8
    let sentenceSpacing: CGFloat = 10
    let translationSpacing: CGFloat = 3

    init(learning: any LearningFeature = AppModel.shared.learning) { self.learning = learning }

    func layout(book: Book, size: CGSize, scale: CGFloat) {
        guard size.width > 56, size.height > 48, scale.isFinite, scale > 0 else { return }
        guard learning.canRead(book) else {
            pages = []; lastLayout = nil
            error = "This book requires access to Cuentiva."
            return
        }
        error = nil
        let key = "\(book.id):\(size):\(scale):\(showsEnglish)"
        guard key != lastLayout else { return }
        lastLayout = key
        let anchor = pages.indices.contains(page) ? pages[page].lines.first : nil
        let width = size.width - 56
        let height = size.height - 48
        // Keep a complete bilingual row on even a very short viewport.
        let fittedScale = min(scale, height / 90)
        let base = UIFont.systemFont(ofSize: 22 * fittedScale)
        spanishFont = UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor,
                             size: 22 * fittedScale)
        englishFont = UIFont.systemFont(ofSize: 17 * fittedScale)
        var result: [Page] = []
        var current: [Line] = []
        var used: CGFloat = 0
        for sentence in book.fullText {
            var spanish = ReaderLineBreaker.fragments(sentence.spanish, width: Double(width), font: spanishFont as CTFont)
            var english = showsEnglish ? ReaderLineBreaker.fragments(sentence.english, width: Double(width), font: englishFont as CTFont) : []
            // Both texts retain their original order and punctuation. Balance the shorter
            // language into more lines where possible, rather than adding a paragraph below.
            let count = max(spanish.count, english.count)
            ReaderLineBreaker.balance(&spanish, to: count)
            if showsEnglish { ReaderLineBreaker.balance(&english, to: count) }
            for index in 0..<count {
                let es = spanish.indices.contains(index) ? spanish[index] : nil
                let en = english.indices.contains(index) ? english[index] : nil
                let row = Line(sentenceID: sentence.id, spanishOffset: es?.offset ?? sentence.spanish.utf16.count,
                    englishOffset: en?.offset ?? sentence.english.utf16.count,
                    spanish: es?.text ?? "", english: en?.text ?? "",
                    speaker: index == 0 ? sentence.speaker : nil, startsSentence: index == 0)
                let rowHeight = (row.spanish.isEmpty ? 0 : ceil(spanishFont.lineHeight))
                    + (row.english.isEmpty ? 0 : translationSpacing + ceil(englishFont.lineHeight))
                    + (row.speaker == nil ? 0 : ceil(englishFont.lineHeight) + translationSpacing)
                var gap = current.isEmpty ? 0 : rowSpacing + (row.startsSentence ? sentenceSpacing : 0)
                if !current.isEmpty, used + gap + rowHeight > height {
                    result.append(Page(id: result.count, lines: current))
                    current = []; used = 0; gap = 0
                }
                used += gap + rowHeight
                current.append(row)
            }
        }
        if !current.isEmpty { result.append(Page(id: result.count, lines: current)) }
        pages = result
        if let anchor {
            page = result.lastIndex { candidate in
                candidate.lines.contains { $0.sentenceID == anchor.sentenceID && $0.spanishOffset <= anchor.spanishOffset }
            } ?? min(page, max(0, result.count - 1))
        } else { page = min(page, max(0, result.count - 1)) }
    }

    func move(_ offset: Int) { page = min(max(0, page + offset), max(0, pages.count - 1)) }

}
