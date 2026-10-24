// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.

import CoreText
import Foundation

/// Physical text layout only. Fragment offsets are UTF-16 offsets into the original sentence.
enum ReaderLineBreaker {
    struct Fragment {
        let offset: Int
        let text: String
    }

    static func fragments(_ text: String, width: Double, font: CTFont) -> [Fragment] {
        guard width.isFinite, width > 0 else { return [] }
        let source = text as NSString
        let attributed = NSAttributedString(string: text,
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        var offset = 0
        var result: [Fragment] = []
        while offset < source.length {
            let length = CTTypesetterSuggestLineBreak(typesetter, offset, width)
            let candidate = CTTypesetterCreateLine(typesetter, CFRange(location: offset, length: length))
            let exceedsWidth = CTLineGetTypographicBounds(candidate, nil, nil, nil)
                - CTLineGetTrailingWhitespaceWidth(candidate) > width
            let fitted = length > 0 && !exceedsWidth
                ? length : CTTypesetterSuggestClusterBreak(typesetter, offset, width)
            var safeLength = min(fitted > 0 ? fitted : source.rangeOfComposedCharacterSequence(at: offset).length,
                                 source.length - offset)
            while safeLength > 0 {
                // Rows are shaped independently by SwiftUI, so measure the substring
                // independently too (punctuation can change contextual kerning).
                let fragment = source.substring(with: NSRange(location: offset, length: safeLength))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let isolated = NSAttributedString(string: fragment,
                    attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
                let line = CTLineCreateWithAttributedString(isolated)
                let measured = CTLineGetTypographicBounds(line, nil, nil, nil)
                guard measured > width else { break }
                let lastCluster = source.rangeOfComposedCharacterSequence(at: offset + safeLength - 1)
                let shorter = lastCluster.location - offset
                guard shorter > 0 else { break }
                safeLength = shorter
            }
            let range = NSRange(location: offset, length: safeLength)
            result.append(Fragment(offset: offset, text: source.substring(with: range)))
            offset = NSMaxRange(range)
        }
        return result
    }

    static func balance(_ lines: inout [Fragment], to count: Int) {
        while lines.count < count {
            // Split only at whitespace, and retain it so joining fragments is lossless.
            let candidates = lines.indices.compactMap { index -> (Int, String.Index)? in
                let text = lines[index].text
                let breaks = text.indices.filter {
                    text[$0].isWhitespace && text.index(after: $0) < text.endIndex
                        && text[..<$0].contains { !$0.isWhitespace }
                        && text[text.index(after: $0)...].contains { !$0.isWhitespace }
                }
                guard let split = breaks.min(by: {
                    abs(text.distance(from: text.startIndex, to: $0) - text.count / 2)
                        < abs(text.distance(from: text.startIndex, to: $1) - text.count / 2)
                }) else { return nil }
                return (index, text.index(after: split))
            }
            guard let (index, split) = candidates.max(by: { lines[$0.0].text.count < lines[$1.0].text.count }) else { return }
            let old = lines[index]
            let prefix = String(old.text[..<split])
            lines.replaceSubrange(index...index, with: [Fragment(offset: old.offset, text: prefix),
                Fragment(offset: old.offset + prefix.utf16.count, text: String(old.text[split...]))])
        }
    }
}
