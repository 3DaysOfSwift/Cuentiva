import Foundation
import Testing
@testable import Cuentiva


@Suite @MainActor struct ThemeManagerTests {
    @Test func themeSelectionSurvivesRelaunch() throws {
        let suite = "CuentivaThemeTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let manager = ThemeManager(preferences: preferences, progress: ProgressManager(repository: MemoryProgress()))
        #expect(manager.selectedTheme == .midnight)
        manager.selectedTheme = .library
        let restored = ThemeManager(preferences: preferences, progress: ProgressManager(repository: MemoryProgress()))
        #expect(restored.selectedTheme == .library)
        #expect(restored.theme.colorScheme == .light)
        restored.selectedTheme = .midnight
        #expect(ThemeManager(preferences: preferences, progress: ProgressManager(repository: MemoryProgress())).theme.colorScheme == .dark)
    }
    @Test func obsoleteThemeFallsBackToMidnight() throws {
        let suite = "CuentivaThemeTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set("removed-palette", forKey: "appearance.colourTheme")
        #expect(ThemeManager(preferences: preferences, progress: ProgressManager(repository: MemoryProgress())).selectedTheme == .midnight)
    }
}
