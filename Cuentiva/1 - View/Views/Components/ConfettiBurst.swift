import SwiftUI

/// A finite burst from the bottom corners, drawn without creating particle views.
struct ConfettiBurst: View {
    let start: Date
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                let colours = theme.theme.coverColours + [theme.theme.accent]
                for index in 0..<100 {
                    // Deterministic variation keeps trajectories stable between frames.
                    let seed = Double((index * 73 + 19) % 101) / 100
                    let spread = Double((index * 37 + 11) % 103) / 102
                    let age = elapsed - Double(index % 9) * 0.018
                    guard age >= 0 else { continue }
                    let fromLeft = index.isMultiple(of: 2)
                    let originX = size.width * (fromLeft ? 0.12 : 0.88)
                    let velocityX = (fromLeft ? 1.0 : -1.0) * size.width * (0.10 + spread * 0.42)
                    let velocityY = -size.height * (0.78 + seed * 0.45)
                    let x = originX + velocityX * age
                    let y = size.height + 12 + velocityY * age + size.height * 0.40 * age * age
                    var particle = context
                    particle.opacity = max(0, min(1, (3.1 - age) / 0.65))
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .degrees(Double(index * 29) + age * (180 + seed * 420)))
                    let width = 5 + spread * 5
                    let height = (8 + seed * 7) * (0.35 + abs(cos(age * 7 + seed * 6)) * 0.65)
                    let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
                    particle.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(colours[index % colours.count]))
                }
            }
        }
    }
}
