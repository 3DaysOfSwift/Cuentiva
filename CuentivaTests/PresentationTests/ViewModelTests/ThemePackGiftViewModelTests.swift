import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct ThemePackGiftViewModelTests {
    @Test func installationFailureIsVisibleAndRetryPreservesSelectedTheme() async throws {
        let repository = MemoryProgress()
        var value = LearnerProgress()
        value.completed = Set((0..<10).map { "book-\($0)" })
        try await repository.save(value)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let suite = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let theme = ThemeManager(preferences: preferences, progress: progress)
        theme.selectedTheme = .midnight
        let model = ThemePackGiftViewModel(pack: .storybook, progress: progress)
        await repository.setFailure(true)
        await model.install(keeping: theme)
        #expect(model.error != nil)
        #expect(!model.installed)
        #expect(!model.installing)
        #expect(theme.selectedTheme == .midnight)
        await repository.setFailure(false)
        await model.install(keeping: theme)
        #expect(model.error == nil)
        #expect(model.installed)
        #expect(theme.availableThemes.contains(.rose))
        #expect(theme.selectedTheme == .midnight)
        let saves = await repository.saveAttempts
        await model.install(keeping: theme)
        #expect(await repository.saveAttempts == saves)
    }
}
