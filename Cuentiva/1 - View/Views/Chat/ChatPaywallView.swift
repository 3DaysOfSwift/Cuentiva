import SwiftUI

struct ChatPaywallView: View {
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Earn your next conversation").font(.system(.title, design: .serif))
            Text("Complete a new story to earn 1 doubloon, then spend it on a Spanish topic chat. Keep talking until you leave the screen. No charge per message.")
            Text("Doubloons are earned by reading. They aren’t available to buy. Conversations use Apple Intelligence on this device.")
                .foregroundStyle(theme.theme.muted)
        }
    }
}
