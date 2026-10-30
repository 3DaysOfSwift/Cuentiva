//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct StorytellerRevealViewModelTests {
    @Test(.timeLimit(.minutes(1)))
    func retryTaskIsSharedAndDepartureCancelsScreenPreparation() async {
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { entered.continuation.finish(); release.continuation.finish() }
        let feature = FantasyManager(repository: HeldPreparationLoad(entered: entered.continuation, release: release.stream), generator: FantasyTestGenerator())
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { false }, currentIcon: { nil })
        let first = model.retryPreparation()
        var events = entered.stream.makeAsyncIterator()
        _ = await events.next()
        let duplicate = model.retryPreparation()
        #expect(first == duplicate)
        model.cancelTasks()
        #expect(first.isCancelled)
        release.continuation.finish()
        await first.value
        await duplicate.value
        #expect(!model.ready)
        #expect(model.error == nil)
        await model.retryPreparation().value
        #expect(model.ready)
    }

    @Test(.timeLimit(.minutes(1)))
    func foregroundRefreshSharesTaskAndReleasesAfterDeparture() async {
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { entered.continuation.finish(); release.continuation.finish() }
        let generator = HeldPreparationAvailability(entered: entered.continuation, release: release.stream)
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: generator)
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { false }, currentIcon: { nil })
        let first = model.refreshAvailability()
        var events = entered.stream.makeAsyncIterator()
        _ = await events.next()
        let duplicate = model.refreshAvailability()
        #expect(first == duplicate)
        model.cancelTasks()
        #expect(first.isCancelled)
        release.continuation.finish()
        await first.value
        await duplicate.value
        let next = model.refreshAvailability()
        #expect(next != first)
        await next.value
        #expect(!next.isCancelled)
    }

    @Test(.timeLimit(.minutes(1)))
    func latePreparationPreservesDraftFromCompletedPreparation() async throws {
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { entered.continuation.finish(); release.continuation.finish() }
        let generator = HeldPreparationAvailability(entered: entered.continuation, release: release.stream)
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: generator)
        try await feature.load()
        _ = try await feature.drawCreature()
        try await feature.saveIdentity(name: "Lirio", biography: "Saved biography")
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { false }, currentIcon: { nil })
        let first = Task { await model.prepare() }
        var events = entered.stream.makeAsyncIterator()
        _ = await events.next()
        await model.prepare()
        #expect(model.ready)
        model.name = "New draft"
        model.biography = "Unsaved biography"
        release.continuation.finish()
        await first.value
        #expect(model.name == "New draft")
        #expect(model.biography == "Unsaved biography")
        #expect(model.error == nil)
    }

    @Test func repeatedPreparationPreservesEditedDraft() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator())
        try await feature.load()
        _ = try await feature.drawCreature()
        try await feature.saveIdentity(name: "Lirio", biography: "Saved biography")
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { false }, currentIcon: { nil })
        await model.prepare()
        model.name = "New draft"
        model.biography = "Unsaved biography"
        await model.prepare()
        #expect(model.name == "New draft")
        #expect(model.biography == "Unsaved biography")
        #expect(model.stage == .details)
        #expect(feature.profile?.identity?.name == "Lirio")
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelledPreparationDoesNotPublishAndCanResume() async {
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { entered.continuation.finish(); release.continuation.finish() }
        let repository = HeldPreparationLoad(entered: entered.continuation, release: release.stream)
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { false }, currentIcon: { nil })
        let request = Task { await model.prepare() }
        var events = entered.stream.makeAsyncIterator()
        _ = await events.next()
        request.cancel()
        release.continuation.finish()
        await request.value
        #expect(!model.ready)
        #expect(model.error == nil)
        #expect(feature.introductionSeen)
        await model.prepare()
        #expect(model.ready)
        #expect(model.error == nil)
    }

    @Test func successfulPreparationRetryClearsLoadingError() async {
        let repository = RetryStorytellerLoad()
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { false }, currentIcon: { nil })
        await model.prepare()
        #expect(!model.ready)
        #expect(model.error != nil)
        await model.prepare()
        #expect(model.ready)
        #expect(model.error == nil)
        #expect(model.stage == .spinning)
        #expect(await repository.loadCount == 2)
    }

    @Test(.timeLimit(.minutes(1)))
    func rejectedSavePreservesDraftAndRetryContinues() async throws {
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { entered.continuation.finish(); release.continuation.finish() }
        let repository = HeldStorytellerSave(entered: entered.continuation, release: release.stream)
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        try await feature.load()
        _ = try await feature.drawCreature()
        try await feature.saveIdentity(name: "Lirio", biography: "The saved biography.")
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { false }, currentIcon: { nil })
        await model.prepare()
        model.name = "Otro"; model.biography = "The new draft biography."
        await repository.holdNextSave(fail: true)
        let request = model.saveAndContinue()
        var events = entered.stream.makeAsyncIterator()
        _ = await events.next()
        #expect(!model.continueRequested)
        release.continuation.finish()
        await request.value
        #expect(model.error != nil)
        #expect(model.savedMessage == nil)
        #expect(!model.continueRequested)
        #expect(!model.busy)
        #expect(model.name == "Otro")
        #expect(model.biography == "The new draft biography.")
        #expect(feature.profile?.identity?.name == "Lirio")
        #expect(await repository.load().profile?.identity?.name == "Lirio")
        await model.saveAndContinue().value
        #expect(model.error == nil)
        #expect(model.savedMessage != nil)
        #expect(model.continueRequested)
        #expect(feature.profile?.identity?.name == "Otro")
        #expect(await repository.load().profile?.identity?.biography == "The new draft biography.")
    }

    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func saveOwnsCompletionAndDepartureSuppressesNavigation(depart: Bool) async throws {
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { entered.continuation.finish(); release.continuation.finish() }
        let repository = HeldStorytellerSave(entered: entered.continuation, release: release.stream)
        let feature = FantasyManager(repository: repository, generator: FantasyTestGenerator())
        try await feature.load()
        _ = try await feature.drawCreature()
        let model = StorytellerRevealViewModel(feature: feature, supportsIcons: { false }, currentIcon: { nil })
        await model.prepare()
        model.name = "Lirio"; model.biography = "A traveller beside the sea."
        await repository.holdNextSave()
        let first = model.saveAndContinue()
        var events = entered.stream.makeAsyncIterator()
        _ = await events.next()
        let duplicate = model.saveAndContinue()
        #expect(model.busy)
        #expect(!model.continueRequested)
        if depart { model.cancelTasks() }
        release.continuation.finish()
        await first.value
        await duplicate.value
        #expect(!model.busy)
        #expect(feature.profile?.identity?.name == "Lirio")
        #expect(await repository.heldSaveCount == 1)
        #expect(model.continueRequested == !depart)
        model.name = "Otro"
        await model.saveAndContinue().value
        #expect(model.continueRequested)
        #expect(feature.profile?.identity?.name == "Otro")
    }

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

private actor HeldStorytellerSave: FantasyRepository {
    private var archive = FantasyArchive()
    private var shouldHold = false
    private var failHeldSave = false
    private(set) var heldSaveCount = 0
    let entered: AsyncStream<Void>.Continuation
    let release: AsyncStream<Void>
    init(entered: AsyncStream<Void>.Continuation, release: AsyncStream<Void>) {
        self.entered = entered; self.release = release
    }
    func holdNextSave(fail: Bool = false) { shouldHold = true; failHeldSave = fail }
    func load() -> FantasyArchive { archive }
    func save(_ value: FantasyArchive) async throws {
        if shouldHold {
            shouldHold = false
            heldSaveCount += 1
            entered.yield(())
            for await _ in release { break }
            if failHeldSave { throw AppFailure.unavailable("Save rejected") }
        }
        // Simulate a storage commit that completes despite caller cancellation.
        archive = value
    }
}

private actor RetryStorytellerLoad: FantasyRepository {
    private(set) var loadCount = 0
    func load() throws -> FantasyArchive {
        loadCount += 1
        if loadCount == 1 { throw AppFailure.unavailable("Read unavailable") }
        return FantasyArchive()
    }
    func save(_ value: FantasyArchive) {}
}

private actor HeldPreparationLoad: FantasyRepository {
    let entered: AsyncStream<Void>.Continuation
    let release: AsyncStream<Void>
    init(entered: AsyncStream<Void>.Continuation, release: AsyncStream<Void>) {
        self.entered = entered; self.release = release
    }
    func load() async throws -> FantasyArchive {
        entered.yield(())
        for await _ in release { break }
        var archive = FantasyArchive()
        archive.introductionSeen = true
        return archive
    }
    func save(_ value: FantasyArchive) {}
}

private actor HeldPreparationAvailability: FantasyGenerator {
    let entered: AsyncStream<Void>.Continuation
    let release: AsyncStream<Void>
    private var requested = false
    init(entered: AsyncStream<Void>.Continuation, release: AsyncStream<Void>) {
        self.entered = entered; self.release = release
    }
    func availabilityMessage() async -> String? {
        if !requested {
            requested = true
            entered.yield(())
            for await _ in release { break }
        }
        return nil
    }
    func identity(name: String, biography: String, creature: FantasyCreature) async throws -> FantasyIdentity {
        try await FantasyTestGenerator().identity(name: name, biography: biography, creature: creature)
    }
    func story(memory: String, profile: FantasyProfile) async throws -> FantasyStory {
        try await FantasyTestGenerator().story(memory: memory, profile: profile)
    }
}
