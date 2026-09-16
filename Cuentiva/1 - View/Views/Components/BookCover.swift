import SwiftUI

struct BookCover: View {
    @Environment(ThemeManager.self) private var theme
    let book: Book
    var completed = false
    var compact = false
    @ScaledMetric(relativeTo: .title3) private var compactHeight = 220.0
    @ScaledMetric(relativeTo: .largeTitle) private var fullHeight = 310.0
    private var color: Color {
        theme.theme.coverColours[book.palette % theme.theme.coverColours.count]
    }
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                color
                Circle().stroke(theme.theme.coverInk.opacity(0.12), lineWidth: 35).frame(width: 180).offset(x: 65, y: 85)
                Rectangle().fill(theme.theme.coverShadow.opacity(0.1)).frame(width: 8).frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                    HStack { Text("CUENTIVA / \(book.level)").font(.system(size: 9, weight: .bold, design: .monospaced)); Spacer() }
                    Text(book.title).font(.system(compact ? .title3 : .largeTitle, design: .serif, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: book.symbol).font(.system(size: compact ? 38 : 70, weight: .ultraLight)).frame(maxWidth: .infinity).padding(.vertical, compact ? 8 : 10)
                    Spacer(minLength: 4)
                    Text(book.author.uppercased()).font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1)
                }.padding(compact ? 17 : 25).foregroundStyle(theme.theme.coverInk)
            }
            if completed {
                Image(systemName: "checkmark.seal.fill").font(.title2).symbolRenderingMode(.palette)
                    .foregroundStyle(theme.theme.onAccent, theme.theme.accent).padding(9)
            }
        }.frame(height: compact ? compactHeight : fullHeight).clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: color.opacity(0.18), radius: 10, x: 0, y: 5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(book.title), \(book.level)\(completed ? ", completed" : "")")
    }
}
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
struct InlineError: View {
    @Environment(ThemeManager.self) private var theme
    let message: String?
    var body: some View { if let message { Label(message, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(theme.theme.error).fixedSize(horizontal: false, vertical: true).accessibilityLabel("Notice: \(message)") } }
}
