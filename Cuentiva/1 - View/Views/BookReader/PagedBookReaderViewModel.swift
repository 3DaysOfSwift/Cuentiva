// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.

import Observation
import SwiftUI
import UIKit

/// Pagination is presentation state. Access to the text remains owned by LearningFeature.
@MainActor @Observable final class PagedBookReaderViewModel {
    struct Passage: Identifiable {
        let id: String
        let spanish: String
        let english: String
        let speaker: String?
    }
    struct Page: Identifiable {
        let id: Int
        let passages: [Passage]
    }
    private let learning: any LearningFeature
    private(set) var pages: [Page] = []
    var page = 0
    var showsEnglish = true
    var error: String?
    private var lastLayout: String?
    let spanishSize: CGFloat = 22
    let englishSize: CGFloat = 17
    let passageSpacing: CGFloat = 18
    let translationSpacing: CGFloat = 5

    init(learning: any LearningFeature = AppModel.shared.learning) { self.learning = learning }

    func layout(book: Book, size: CGSize, scale: CGFloat) {
        guard size.width > 0, size.height > 0 else { return }
        guard learning.canRead(book) else {
            pages = []
            error = "This book requires access to Cuentiva."
            return
        }
        error = nil
        let key = "\(book.id):\(size):\(scale):\(showsEnglish)"
        guard key != lastLayout else { return }
        lastLayout = key
        let anchor = pages.indices.contains(page) ? pages[page].passages.first?.id : nil
        let width = max(1, size.width - 56)
        let height = max(1, size.height - 48)
        let spanishFont = UIFont(descriptor: UIFont.systemFont(ofSize: spanishSize * scale).fontDescriptor.withDesign(.serif)
            ?? UIFont.systemFont(ofSize: spanishSize * scale).fontDescriptor, size: spanishSize * scale)
        let englishFont = UIFont.systemFont(ofSize: englishSize * scale)
        var result: [Page] = []
        var current: [Passage] = []
        var used: CGFloat = 0
        for sentence in book.fullText {
            let passage = Passage(id: sentence.id, spanish: sentence.spanish,
                                  english: sentence.english, speaker: sentence.speaker)
            let measured = measuredHeight(passage, width: width, spanishFont: spanishFont, englishFont: englishFont)
            if !current.isEmpty, used + passageSpacing + measured > height {
                result.append(Page(id: result.count, passages: current))
                current = []; used = 0
            }
            // Very long passages get their own page. The page view fits the entire pair
            // at a smaller type size rather than clipping text or introducing vertical scrolling.
            used += (current.isEmpty ? 0 : passageSpacing) + measured
            current.append(passage)
        }
        if !current.isEmpty { result.append(Page(id: result.count, passages: current)) }
        pages = result
        page = anchor.flatMap { id in result.firstIndex { $0.passages.contains { $0.id == id } } }
            ?? min(page, max(0, result.count - 1))
    }

    func move(_ offset: Int) { page = min(max(0, page + offset), max(0, pages.count - 1)) }

    private func measuredHeight(_ passage: Passage, width: CGFloat, spanishFont: UIFont, englishFont: UIFont) -> CGFloat {
        func height(_ text: String, font: UIFont) -> CGFloat {
            ceil((text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height)
        }
        return height(passage.spanish, font: spanishFont)
            + (showsEnglish ? translationSpacing + height(passage.english, font: englishFont) : 0)
            + (passage.speaker == nil ? 0 : englishFont.lineHeight + translationSpacing)
    }
}
