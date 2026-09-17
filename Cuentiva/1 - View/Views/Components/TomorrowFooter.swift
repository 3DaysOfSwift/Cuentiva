import SwiftUI

struct TomorrowFooter: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: 20) {
            Text("Vuelve mañana")
                .font(.system(.title2, design: .serif, weight: .medium))
                .multilineTextAlignment(.center)
            Image("SpiritFox")
                .resizable().scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(theme.theme.accent.opacity(0.18), lineWidth: 1) }
                .accessibilityHidden(true)
        }
        .foregroundStyle(theme.theme.ink)
        .frame(width: 190)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vuelve mañana. Come back tomorrow.")
    }
}
