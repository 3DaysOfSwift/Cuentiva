import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct AppIconSettingsViewModelTests {
    @Test func successfulPreparationRetryClearsLoadFailure() async {
        let repository = RetryIconProfileRepository()
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        let model = AppIconSettingsViewModel(feature: feature, supportsIcons: { true },
                                            currentIcon: { nil }, changeIcon: { _ in })
        await model.prepare()
        #expect(model.iconMessage != nil)
        await repository.allowLoad()
        await model.prepare()
        #expect(model.iconMessage == nil)
    }

    @Test func loadingFailureDoesNotReplaceConfirmedIconChange() async {
        let feature = FantasyManager(repository: RetryIconProfileRepository(), generator: FantasyTestGenerator())
        var icon: String? = "Storyteller"
        let model = AppIconSettingsViewModel(feature: feature, supportsIcons: { true },
                                            currentIcon: { icon }, changeIcon: { icon = $0 })
        await model.restorePipaIcon()
        let confirmation = model.iconMessage
        #expect(confirmation != nil)
        await model.prepare()
        #expect(model.iconMessage == confirmation)
        #expect(model.selectedIcon == nil)
    }

    @Test func restoringOriginalIconReportsConfirmedSelection() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator())
        var icon: String? = "Storyteller"
        let model = AppIconSettingsViewModel(feature: feature, supportsIcons: { true }, currentIcon: { icon }, changeIcon: { icon = $0 })
        await model.prepare()
        await model.restorePipaIcon()
        #expect(model.selectedIcon == nil)
        #expect(model.iconMessage != nil)
        #expect(!model.changingIcon)
    }
}

private actor RetryIconProfileRepository: FantasyRepository {
    private var fails = true
    func allowLoad() { fails = false }
    func load() async throws -> FantasyArchive {
        if fails { throw AppFailure.unavailable("Controlled load failure") }
        return FantasyArchive()
    }
    func save(_ archive: FantasyArchive) async throws {}
}
