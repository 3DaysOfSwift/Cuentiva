//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

/// One app-owned palette. Pack eligibility and installation belong to learner progress.
@MainActor @Observable final class ThemeManager {
    private static let preferenceKey = "appearance.colourTheme"
    @ObservationIgnored private let preferences: UserDefaults
    private let progress: any ProgressFeature
    private var preferredTheme: ColourThemeID
    var availableThemes: [ColourThemeID] { progress.snapshot.availableThemes }
    var selectedTheme: ColourThemeID {
        get {
            // Restore the last selected palette immediately. An unloaded archive
            // is not evidence that an installed theme is unavailable.
            if !progress.loaded { return preferredTheme }
            return availableThemes.contains(preferredTheme) ? preferredTheme : .midnight
        }
        set {
            guard availableThemes.contains(newValue) else { return }
            preferredTheme = newValue
            preferences.set(newValue.rawValue, forKey: Self.preferenceKey)
        }
    }
    var theme: AppColourTheme { selectedTheme.palette }
    init(preferences: UserDefaults = .standard, progress: any ProgressFeature = AppModel.shared.progress) {
        self.preferences = preferences
        self.progress = progress
        preferredTheme = preferences.string(forKey: Self.preferenceKey).flatMap(ColourThemeID.init(rawValue:)) ?? .midnight
    }
}
