//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

/// Keeps a word on one line unless the tile exceeds the entire available row.
struct WordTileLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(width: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading, proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func arrangement(width: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        let available = max(0, width ?? ideal.reduce(0) { $0 + $1.width + spacing })
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for (index, size) in ideal.enumerated() {
            let tileWidth = min(size.width, available)
            let measured = subviews[index].sizeThatFits(ProposedViewSize(width: tileWidth, height: nil))
            if x > 0 && x + tileWidth > available {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: tileWidth, height: measured.height))
            x += tileWidth + spacing
            rowHeight = max(rowHeight, measured.height)
        }
        return (CGSize(width: available, height: y + rowHeight), frames)
    }
}
