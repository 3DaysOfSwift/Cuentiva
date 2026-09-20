import SwiftUI

/// A rounded message bubble with a small curved tail at its lower outside corner.
struct ChatBubbleShape: Shape {
    var tailOnRight: Bool

    func path(in rect: CGRect) -> Path {
        let radius = min(18, min(rect.width, rect.height) / 2)
        let left = rect.minX, right = rect.maxX
        let top = rect.minY, bottom = rect.maxY
        var path = Path()
        path.move(to: CGPoint(x: left + radius, y: top))
        path.addLine(to: CGPoint(x: right - radius, y: top))
        path.addQuadCurve(to: CGPoint(x: right, y: top + radius), control: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: bottom - radius))
        path.addCurve(to: CGPoint(x: right + 8, y: bottom),
                      control1: CGPoint(x: right, y: bottom - 8),
                      control2: CGPoint(x: right + 3, y: bottom - 2))
        path.addQuadCurve(to: CGPoint(x: right - radius, y: bottom),
                          control: CGPoint(x: right - 2, y: bottom + 1))
        path.addLine(to: CGPoint(x: left + radius, y: bottom))
        path.addQuadCurve(to: CGPoint(x: left, y: bottom - radius), control: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: left, y: top + radius))
        path.addQuadCurve(to: CGPoint(x: left + radius, y: top), control: CGPoint(x: left, y: top))
        path.closeSubpath()
        return tailOnRight ? path : path.applying(
            CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.minX + rect.maxX, ty: 0))
    }
}
