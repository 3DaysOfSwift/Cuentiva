import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct StorytellerRevealViewModelTests {
    @Test func savedBioReturnsToEditableForm() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        let model = StorytellerRevealViewModel(feature: feature)
        await model.prepare()
        model.name = "James"; model.biography = "A traveller who helps others."
        await model.saveDetails()
        #expect(model.savedMessage != nil)
        let reopened = StorytellerRevealViewModel(feature: feature)
        await reopened.prepare()
        #expect(reopened.stage == .details)
        #expect(reopened.name == "James")
        #expect(reopened.biography == "A traveller who helps others.")
    }

    @Test func fantasyIdentityRevealUsesSavedCreatureAndPersistsCompletion() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator(), draw: { .turtle })
        try await feature.load(); _ = try await feature.drawCreature()
        let model = StorytellerRevealViewModel(feature: feature)
        await model.prepare()
        #expect(model.stage == .creature)
        model.editDetails()
        #expect(model.name == FantasyCreature.turtle.defaultIdentity.name)
        #expect(model.biography == FantasyCreature.turtle.defaultIdentity.biography)
        model.name = "Matt"; model.biography = "I travel and write apps."
        await model.saveDetails()
        #expect(model.savedMessage != nil)
        #expect(model.identity?.name == "Matt")
        #expect(model.name == "Matt")
        #expect(await model.finish())
        #expect(feature.introductionSeen)
    }
    @Test(arguments: FantasyCreature.allCases)
    func iconIsOptInAndCanReturnToPipa(creature: FantasyCreature) async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator(), draw: { creature })
        try await feature.load(); _ = try await feature.drawCreature()
        var icon: String?
        var changes = 0
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { true }, currentIcon: { icon }, changeIcon: {
            icon = $0; changes += 1
        })
        await model.prepare()
        #expect(model.canOfferIcon)
        #expect(changes == 0)
        await model.chooseIconAndEdit()
        #expect(model.stage == .details)
        #expect(model.name == creature.defaultIdentity.name)
        #expect(icon == creature.appIconName)
        #expect(model.usesStorytellerIcon)
        await model.useStorytellerIcon()
        #expect(changes == 1)
        await model.restorePipaIcon()
        #expect(icon == nil)
        #expect(!model.usesStorytellerIcon)
    }

    @Test func iconFailureKeepsExistingIconAndAllowsRetry() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator(), draw: { .fox })
        try await feature.load(); _ = try await feature.drawCreature()
        var shouldFail = true
        var icon: String?
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { true }, currentIcon: { icon }, changeIcon: {
            if shouldFail { throw AppFailure.unavailable("Unavailable") }
            icon = $0
        })
        await model.prepare()
        await model.useStorytellerIcon()
        #expect(!model.usesStorytellerIcon)
        #expect(model.iconMessage?.contains("try again") == true)
        #expect(!model.changingIcon)
        shouldFail = false
        await model.useStorytellerIcon()
        #expect(model.usesStorytellerIcon)
    }

    @Test func unsupportedDeviceDoesNotOfferOrChangeIcon() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        var changes = 0
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { false }, currentIcon: { nil }, changeIcon: { _ in changes += 1 })
        await model.prepare()
        #expect(!model.canOfferIcon)
        await model.useStorytellerIcon()
        #expect(changes == 0)
    }

}
