import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct FantasyWritingViewModelTests {
    @Test func fantasyWriterLoadsItsSavedTales() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        try await feature.createIdentity(name: "Matt", biography: "A traveller")
        let model = FantasyWritingViewModel(feature: feature)
        await model.load(); model.memory = "I danced in Mexico."
        await model.generate()
        #expect(model.story != nil)
        #expect(model.stories.count == 1)
        #expect(model.error == nil)
        #expect(!model.busy)
    }
}
