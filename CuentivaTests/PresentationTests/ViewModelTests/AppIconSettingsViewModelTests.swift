import Foundation
import Testing
@testable import Cuentiva

@Suite(.timeLimit(.minutes(1))) @MainActor struct AppIconSettingsViewModelTests {
    @Test(arguments: [false, true])
    func cancelledPreparationIgnoresLateOutcomeAndAllowsRetry(fails: Bool) async {
        let repository = HeldIconProfileRepository(fails: fails)
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        let model = AppIconSettingsViewModel(feature: feature, supportsIcons: { true },
                                            currentIcon: { nil }, changeIcon: { _ in })
        let preparation = Task { await model.prepare() }
        await repository.waitForLoad()
        await model.prepare()
        #expect(await repository.loads == 1)
        preparation.cancel()
        await repository.release()
        await preparation.value
        #expect(model.iconMessage == nil)
        await model.prepare()
        #expect(model.iconMessage == nil)
        #expect(await repository.loads == (fails ? 2 : 1))
    }

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


private actor HeldIconProfileRepository: FantasyRepository {
    private let fails: Bool
    private(set) var loads = 0
    private var pending: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    init(fails: Bool) { self.fails = fails }
    func load() async throws -> FantasyArchive {
        loads += 1
        if loads == 1 {
            await withCheckedContinuation { continuation in
                pending = continuation
                arrival?.resume()
                arrival = nil
            }
            if fails { throw AppFailure.unavailable("Controlled late failure") }
        }
        return FantasyArchive()
    }
    func waitForLoad() async {
        if pending != nil { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func release() {
        pending?.resume()
        pending = nil
    }
    func save(_ archive: FantasyArchive) async throws {}
}
