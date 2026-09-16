import SwiftUI

struct AppColourTheme {
    let paper: Color
    let ink: Color
    let accent: Color
    let muted: Color
    static let library = AppColourTheme(paper: Color(red: 0.97, green: 0.96, blue: 0.93), ink: Color(red: 0.13, green: 0.23, blue: 0.22), accent: Color(red: 0.18, green: 0.37, blue: 0.29), muted: Color(red: 0.39, green: 0.43, blue: 0.39))
    static let midnight = AppColourTheme(paper: Color(red: 0.12, green: 0.16, blue: 0.20), ink: .white, accent: Color(red: 0.63, green: 0.83, blue: 0.69), muted: Color(white: 0.73))
}
@MainActor @Observable final class ThemeManager {
    var theme: AppColourTheme = .library
}
struct PrimaryButton: ButtonStyle {
    @Environment(ThemeManager.self) private var theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(17)
            .background(theme.theme.accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(theme.theme.paper)
    }
}
