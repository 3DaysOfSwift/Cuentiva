import SwiftUI

struct DailyPracticeCard: View {
    let completed: Int
    let rewarded: Bool
    let open: () -> Void
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Find the missing word. Build a sentence. Keep the word trail going.")
                    .foregroundStyle(theme.theme.muted)
                HStack {
                    Text("\(completed) of 3 games finished").font(.headline)
                    Spacer()
                    DoubloonBalance(count: 1, earned: rewarded)
                }
                Text(rewarded ? "Today’s doubloon earned · Come back tomorrow" : "From today’s three books · One play-through each · Earn 1 doubloon")
                    .font(.caption).foregroundStyle(theme.theme.muted)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain)
    }
}
