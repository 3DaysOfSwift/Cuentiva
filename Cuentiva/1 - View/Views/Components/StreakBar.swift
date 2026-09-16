import SwiftUI

struct StreakBar: View {
    let count: Int
    let days: [WeekDay]
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        HStack(spacing: 16) {
            Label("\(count) day streak", systemImage: "flame.fill").font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                ForEach(days) { day in
                    VStack(spacing: 5) {
                        Text(day.label).font(.system(size: 9, weight: .semibold))
                        Image(systemName: day.practiced ? "checkmark.circle.fill" : day.today ? "circle.inset.filled" : "circle")
                            .font(.system(size: 11)).opacity(day.practiced || day.today ? 1 : 0.35)
                    }.accessibilityLabel("\(day.id): \(day.practiced ? "practiced" : "not practiced")")
                }
            }
        }.foregroundStyle(theme.theme.accent).padding(.vertical, 17)
    }
}
