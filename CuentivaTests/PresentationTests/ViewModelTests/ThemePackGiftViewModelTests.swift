import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct ThemePackGiftViewModelTests {
    @Test func selectionIsRequiredAndSuccessfulRetryAppliesThemeBeforeDismissal() async throws {
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
        let model = ThemePackGiftViewModel(pack: .storybook, progress: progress, pause: { _ in })
        #expect(!model.canInstall)
        let initialSaves = await repository.saveAttempts
        await model.install(using: theme)
        #expect(await repository.saveAttempts == initialSaves)
        model.previewTheme = .rose
        #expect(model.canInstall)
        #expect(theme.selectedTheme == .midnight)
        await repository.setFailure(true)
        await model.install(using: theme)
        #expect(model.error != nil)
        #expect(!model.installed)
        #expect(!model.installing)
        #expect(!model.installationConfirmed)
        #expect(!model.shouldDismiss)
        #expect(theme.selectedTheme == .midnight)
        await repository.setFailure(false)
        await model.install(using: theme)
        #expect(model.error == nil)
        #expect(model.installed)
        #expect(theme.availableThemes.contains(.rose))
        #expect(theme.selectedTheme == .rose)
        #expect(model.installationConfirmed)
        #expect(model.shouldDismiss)
        #expect(!model.canInstall)
        let saves = await repository.saveAttempts
        await model.install(using: theme)
        #expect(await repository.saveAttempts == saves)
    }
}
