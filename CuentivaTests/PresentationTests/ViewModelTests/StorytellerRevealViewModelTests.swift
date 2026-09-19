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
        model.name = "Matt"; model.biography = "I travel and write apps."
        await model.generateIdentity()
        #expect(model.stage == .identity)
        #expect(model.identity?.name == "Lirio")
        #expect(model.name.isEmpty)
        #expect(await model.finish())
        #expect(feature.introductionSeen)
    }
}
