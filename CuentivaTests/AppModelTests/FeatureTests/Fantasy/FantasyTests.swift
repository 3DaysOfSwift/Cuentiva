//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct FantasyTests {
    @Test func skippedIntroductionPersistsWithoutFakeIdentity() async throws {
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        try await feature.load()
        #expect(!feature.introductionSeen)
        try await feature.finishIntroduction()
        let relaunched = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        try await relaunched.load()
        #expect(relaunched.introductionSeen)
        #expect(relaunched.profile == nil)
    }
    @Test func invalidStoryPairsAreRejected() {
        let invalid = FantasyStory(title: "Hola", englishTitle: "Hello", sentences: [.init(spanish: "Hola", english: "")])
        #expect(throws: (any Error).self) { try FantasyValidation.story(invalid) }
    }

    @Test func creatureSurvivesRelaunchAndStoriesStayPrivate() async throws {
        let repository = FantasyTestRepository()
        let first = FantasyManager(repository: repository, generator: FantasyTestGenerator(), draw: { .turtle })
        try await first.load()
        #expect(try await first.drawCreature() == .turtle)
        let revealNumber = try #require(first.profile?.revealNumber)
        #expect((1...999).contains(revealNumber))
        #expect((revealNumber - 1) % FantasyCreature.allCases.count == 0)
        let next = FantasyManager(repository: repository, generator: FantasyTestGenerator(), draw: { .fox })
        try await next.load()
        #expect(try await next.drawCreature() == .turtle)
        #expect(next.profile?.revealNumber == revealNumber)
        try await next.createIdentity(name: "Matthew", biography: "I travel and build apps.")
        let story = try await next.createStory(memory: "I danced in Mexico.")
        #expect(next.profile?.identity?.name == "Lirio")
        #expect(next.stories.map(\.id) == [story.id])
    }
    @Test func failedSaveDoesNotRevealUnpersistedCreature() async throws {
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        try await feature.load(); await repository.setFailure()
        await #expect(throws: (any Error).self) { _ = try await feature.drawCreature() }
        #expect(feature.profile == nil)
    }
    @Test func malformedIdentityDoesNotReplaceProfile() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator(invalid: true))
        try await feature.load(); _ = try await feature.drawCreature()
        await #expect(throws: (any Error).self) { try await feature.createIdentity(name: "Matt", biography: "A traveller") }
        #expect(feature.profile?.identity == nil)
        #expect(feature.profile?.creature != nil)
    }
}
