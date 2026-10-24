import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct AppIconSettingsViewModelTests {
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
