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
    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func generationExcludesEditsAndCancellationAllowsRetry(cancel: Bool) async throws {
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { entered.continuation.finish(); release.continuation.finish() }
        let generator = HeldStoryGenerator(entered: entered.continuation, release: release.stream)
        let repository = FantasyTestRepository()
        let feature = FantasyManager(repository: repository, generator: generator, draw: { .turtle })
        try await feature.load()
        _ = try await feature.drawCreature()
        try await feature.saveIdentity(name: "Lirio", biography: "A traveller beside the sea.")
        let request = Task { try await feature.createStory(memory: "A day beside the sea.") }
        var events = entered.stream.makeAsyncIterator()
        _ = await events.next()
        do {
            try await feature.saveIdentity(name: "Otro", biography: "A different traveller.")
            Issue.record("An edit was accepted while story generation was pending")
        } catch AppFailure.busy {
            // The Feature owns admission across the generator suspension.
        } catch {
            Issue.record("Expected busy rejection, received: \(error)")
        }
        #expect(feature.profile?.identity?.name == "Lirio")
        #expect(feature.stories.isEmpty)
        if cancel { request.cancel() }
        release.continuation.finish()
        if cancel {
            await #expect(throws: CancellationError.self) { _ = try await request.value }
            #expect(feature.stories.isEmpty)
            #expect(await repository.load().stories.isEmpty)
            _ = try await feature.createStory(memory: "A second day beside the sea.")
        } else {
            _ = try await request.value
        }
        #expect(feature.stories.count == 1)
        #expect(await repository.load().stories.map(\.id) == feature.stories.map(\.id))
        try await feature.saveIdentity(name: "Otro", biography: "A different traveller.")
        #expect(feature.profile?.identity?.name == "Otro")
    }

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

private actor HeldStoryGenerator: FantasyGenerator {
    let entered: AsyncStream<Void>.Continuation
    let release: AsyncStream<Void>
    private var requests = 0
    init(entered: AsyncStream<Void>.Continuation, release: AsyncStream<Void>) {
        self.entered = entered
        self.release = release
    }
    func identity(name: String, biography: String, creature: FantasyCreature) async throws -> FantasyIdentity {
        try await FantasyTestGenerator().identity(name: name, biography: biography, creature: creature)
    }
    func story(memory: String, profile: FantasyProfile) async throws -> FantasyStory {
        requests += 1
        if requests == 1 {
            entered.yield(())
            for await _ in release { break }
        }
        // Deliberately return a late result even when the caller has cancelled.
        return try await FantasyTestGenerator().story(memory: memory, profile: profile)
    }
}
