import SwiftUI

enum ColourThemeID: String, CaseIterable, Identifiable {
    case library, midnight
    var id: Self { self }
    var title: String { switch self { case .library: "Library"; case .midnight: "Midnight" } }
    var palette: AppColourTheme { switch self { case .library: .library; case .midnight: .midnight } }
}

struct AppColourTheme {
    let paper: Color
    let surface: Color
    let ink: Color
    let accent: Color
    let onAccent: Color
    let muted: Color
    let error: Color
    let colorScheme: ColorScheme
    let checkButtonBackground = Color(red: 0.18, green: 0.37, blue: 0.29)
    let checkButtonForeground: Color = .white
    let coverInk: Color = .white
    let coverShadow: Color = .black
    // Book artwork keeps its identity while surrounding controls follow the theme.
    let coverColours: [Color] = [
        Color(red: 0.72, green: 0.35, blue: 0.23),
        Color(red: 0.25, green: 0.39, blue: 0.43),
        Color(red: 0.43, green: 0.45, blue: 0.27),
        Color(red: 0.51, green: 0.35, blue: 0.40),
        Color(red: 0.67, green: 0.46, blue: 0.24)
    ]
    static let library = AppColourTheme(
        paper: Color(red: 0.97, green: 0.96, blue: 0.93),
        surface: Color(red: 0.995, green: 0.99, blue: 0.98),
        ink: Color(red: 0.13, green: 0.23, blue: 0.22),
        accent: Color(red: 0.18, green: 0.37, blue: 0.29),
        onAccent: .white,
        muted: Color(red: 0.39, green: 0.43, blue: 0.39),
        error: Color(red: 0.68, green: 0.16, blue: 0.16),
        colorScheme: .light)
    static let midnight = AppColourTheme(
        paper: Color(red: 0.12, green: 0.16, blue: 0.20),
        surface: Color(red: 0.18, green: 0.23, blue: 0.28),
        ink: Color(red: 0.96, green: 0.97, blue: 0.95),
        accent: Color(red: 0.63, green: 0.83, blue: 0.69),
        onAccent: Color(red: 0.10, green: 0.18, blue: 0.14),
        muted: Color(red: 0.73, green: 0.78, blue: 0.81),
        error: Color(red: 1.0, green: 0.60, blue: 0.57),
        colorScheme: .dark)
}
