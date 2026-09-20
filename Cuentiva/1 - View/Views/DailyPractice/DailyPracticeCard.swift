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
                Text(rewarded ? "Today’s rewards earned · Come back tomorrow" : "From today’s three books · One play-through each · Earn 1 doubloon per game")
                    .font(.caption).foregroundStyle(theme.theme.muted)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(rewarded ? theme.theme.rewardGold : theme.theme.accent.opacity(0.2), lineWidth: rewarded ? 2 : 1)
                }
        }.buttonStyle(.plain)
    }
}
