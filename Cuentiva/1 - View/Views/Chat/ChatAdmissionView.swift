import SwiftUI

struct ChatAdmissionView: View {
    let coins: Int
    let confirm: () -> Void
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                DoubloonIcon(size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text("1 doubloon").font(.title2.weight(.semibold))
                    Text("One topic. Keep the conversation going.")
                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                }
                Spacer(minLength: 0)
            }
            DoubloonBalance(count: coins).font(.subheadline)
            Text("Charged only after your first successful reply. No charge per message. Leaving this screen ends the topic.")
                .font(.footnote).foregroundStyle(theme.theme.muted)
            SlideToStartView(confirm: confirm)
        }
        .padding(20)
        .background(theme.theme.paper)
        .overlay(alignment: .top) { Rectangle().fill(theme.theme.muted.opacity(0.45)).frame(height: 1) }
    }
}
