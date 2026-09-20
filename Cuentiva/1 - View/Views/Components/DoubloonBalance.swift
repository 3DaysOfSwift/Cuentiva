import SwiftUI

struct DoubloonBalance: View {
    let count: Int
    var earned = false
    var size: CGFloat = 28
    @Environment(ThemeManager.self) private var theme

    private var label: String {
        "\(earned ? "+" : "")\(count) \(count == 1 ? "doubloon" : "doubloons")"
    }
    var body: some View {
        HStack(spacing: 8) {
            DoubloonIcon(size: size)
            Text(label).monospacedDigit()
        }
        .foregroundStyle(theme.theme.rewardGold)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label)\(earned ? " earned" : " available")")
    }
}
