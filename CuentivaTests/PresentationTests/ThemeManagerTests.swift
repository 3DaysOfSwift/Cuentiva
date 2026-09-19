import Foundation
import Testing
@testable import Cuentiva


@Suite @MainActor struct ThemeManagerTests {
    @Test func themeSelectionSurvivesRelaunch() throws {
        let suite = "CuentivaThemeTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let manager = ThemeManager(preferences: preferences, progress: ProgressManager(repository: MemoryProgress()))
        #expect(manager.selectedTheme == .library)
        manager.selectedTheme = .midnight
        let restored = ThemeManager(preferences: preferences, progress: ProgressManager(repository: MemoryProgress()))
        #expect(restored.selectedTheme == .midnight)
        #expect(restored.theme.colorScheme == .dark)
        restored.selectedTheme = .library
        #expect(ThemeManager(preferences: preferences, progress: ProgressManager(repository: MemoryProgress())).theme.colorScheme == .light)
    }
    @Test func obsoleteThemeFallsBackToLibrary() throws {
        let suite = "CuentivaThemeTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set("removed-palette", forKey: "appearance.colourTheme")
        #expect(ThemeManager(preferences: preferences, progress: ProgressManager(repository: MemoryProgress())).selectedTheme == .library)
    }
}
