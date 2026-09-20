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
    @Test func installedThemeIsUsedBeforeAndAfterProgressLoads() async throws {
        let suite = "CuentivaThemeTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set("lavender", forKey: "appearance.colourTheme")
        let repository = MemoryProgress()
        var saved = LearnerProgress()
        saved.installedThemePacks = [ThemePack.storybook.rawValue]
        try await repository.save(saved)
        let progress = ProgressManager(repository: repository)
        let manager = ThemeManager(preferences: preferences, progress: progress)
        #expect(!progress.loaded)
        #expect(manager.selectedTheme == .lavender)
        #expect(manager.theme.colorScheme == .light)
        try await progress.load()
        #expect(manager.selectedTheme == .lavender)
        #expect(manager.theme.colorScheme == .light)
    }

    @Test func unavailableThemeFallsBackOnlyAfterProgressIsKnown() async throws {
        let suite = "CuentivaThemeTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set("lavender", forKey: "appearance.colourTheme")
        let progress = ProgressManager(repository: MemoryProgress())
        let manager = ThemeManager(preferences: preferences, progress: progress)
        #expect(manager.selectedTheme == .lavender)
        try await progress.load()
        #expect(manager.selectedTheme == .midnight)
        manager.selectedTheme = .lavender
        #expect(manager.selectedTheme == .midnight)
    }

    @Test func obsoleteThemeFallsBackToMidnight() throws {
        let suite = "CuentivaThemeTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set("removed-palette", forKey: "appearance.colourTheme")
        #expect(ThemeManager(preferences: preferences, progress: ProgressManager(repository: MemoryProgress())).selectedTheme == .midnight)
    }
}
