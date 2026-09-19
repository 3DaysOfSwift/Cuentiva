import SwiftUI

struct PrimaryButton: ButtonStyle {
    var palette: AppColourTheme? = nil
    @Environment(ThemeManager.self) private var theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(17)
            .background((palette ?? theme.theme).accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle((palette ?? theme.theme).onAccent)
    }
}
