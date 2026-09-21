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

@Suite @MainActor struct StorytellerDetailsTests {
    @Test func editedIdentitySavesWithoutAIAndPreservesItOnFailure() async throws {
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: UnavailableFantasyGenerator(), draw: { .fox })
        try await feature.load(); _ = try await feature.drawCreature()
        let defaults = FantasyCreature.fox.defaultIdentity
        try await feature.saveIdentity(name: defaults.name, biography: defaults.biography)
        let reopened = FantasyManager(repository: repository, generator: UnavailableFantasyGenerator())
        try await reopened.load()
        #expect(reopened.profile?.identity == defaults)
        #expect(reopened.introductionSeen)
        await #expect(throws: AppFailure.self) { try await feature.saveIdentity(name: "Two Names", biography: defaults.biography) }
        await repository.setFailure()
        await #expect(throws: (any Error).self) { try await feature.saveIdentity(name: "Faro", biography: "A new biography.") }
        #expect(feature.profile?.identity == defaults)
    }

    @Test func saveAndReopenBioWithoutAI() async throws {
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: UnavailableFantasyGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        await feature.refreshAvailability()
        #expect(feature.availabilityMessage != nil)
        try await feature.saveDetails(name: " James ", biography: " A traveller who helps others. ")
        let reopened = FantasyManager(repository: repository, generator: UnavailableFantasyGenerator())
        try await reopened.load()
        #expect(reopened.profile?.details?.name == "James")
        #expect(reopened.profile?.details?.biography == "A traveller who helps others.")
        #expect(reopened.profile?.identity == nil)
        #expect(reopened.profile?.revealNumber == feature.profile?.revealNumber)
    }
    @Test func saveFailureKeepsPreviousBio() async throws {
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: UnavailableFantasyGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        try await feature.saveDetails(name: "James", biography: "The original bio.")
        await repository.setFailure()
        await #expect(throws: (any Error).self) { try await feature.saveDetails(name: "James", biography: "A replacement.") }
        #expect(feature.profile?.details?.biography == "The original bio.")
    }
    @Test func generationFailureDoesNotEraseSavedBio() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: UnavailableFantasyGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        try await feature.saveDetails(name: "James", biography: "A traveller.")
        await #expect(throws: (any Error).self) { try await feature.createIdentity(name: "James", biography: "A traveller.") }
        #expect(feature.profile?.details?.biography == "A traveller.")
    }
}
