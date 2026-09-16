import SwiftUI

/// One instance is owned by the App and supplied to every scene and sheet.
/// Theme is presentation state, so its owner remains in the View layer.
@MainActor @Observable final class ThemeManager {
    private static let preferenceKey = "appearance.colourTheme"
    @ObservationIgnored private let preferences: UserDefaults
    var selectedTheme: ColourThemeID {
        didSet { preferences.set(selectedTheme.rawValue, forKey: Self.preferenceKey) }
    }
    var theme: AppColourTheme { selectedTheme.palette }
    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        selectedTheme = preferences.string(forKey: Self.preferenceKey).flatMap(ColourThemeID.init(rawValue:)) ?? .library
    }
}
