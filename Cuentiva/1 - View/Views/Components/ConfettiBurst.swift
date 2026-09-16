import SwiftUI

/// Launch below the viewport so particles spread before crossing its bottom edge.
struct ConfettiBurst: View {
    static let duration = 4.2
    let start: Date
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                let colours = theme.theme.coverColours + [theme.theme.accent]
                for index in 0..<80 {
                    // Deterministic variation keeps trajectories stable between frames.
                    let seed = Double((index * 73 + 19) % 101) / 100
                    let spread = Double((index * 37 + 11) % 103) / 102
                    let age = elapsed - Double(index % 9) * 0.018
                    guard age >= 0 else { continue }
                    let fromLeft = index.isMultiple(of: 2)
                    let originX = size.width * (fromLeft ? 0.12 : 0.88)
                    let velocityX = (fromLeft ? 1.0 : -1.0) * size.width * (-0.08 + spread * 0.52)
                    let velocityY = -size.height * (0.85 + seed * 0.25)
                    let x = originX + velocityX * age
                    // The hidden initial flight disperses each plume before it is visible.
                    let y = size.height * 1.38 + velocityY * age + size.height * 0.28 * age * age
                    guard y > -20, y < size.height + 20 else { continue }
                    var particle = context
                    particle.opacity = max(0, min(1, (Self.duration - age) / 0.9))
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .degrees(Double(index * 29) + age * (70 + seed * 160)))
                    let width = 4 + spread * 4
                    let height = (6 + seed * 5) * (0.35 + abs(cos(age * 7 + seed * 6)) * 0.65)
                    let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
                    particle.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(colours[index % colours.count]))
                }
            }.clipped()
        }
    }
}
