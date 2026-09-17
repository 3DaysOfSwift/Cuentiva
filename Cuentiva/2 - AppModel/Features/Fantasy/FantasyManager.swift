import Foundation
import Observation

@MainActor protocol FantasyFeature: AnyObject, Sendable {
    var profile: FantasyProfile? { get }
    var introductionSeen: Bool { get }
    var availabilityMessage: String? { get }
    func refreshAvailability() async
    func finishIntroduction() async throws
    var stories: [FantasyStory] { get }
    func load() async throws
    func drawCreature() async throws -> FantasyCreature
    func saveDetails(name: String, biography: String) async throws
    func createIdentity(name: String, biography: String) async throws
    func createStory(memory: String) async throws -> FantasyStory
}

@MainActor @Observable final class FantasyManager: FantasyFeature {
    private var archive = FantasyArchive()
    private var loaded = false
    private var busy = false
    private let repository: any FantasyRepository
    private let generator: any FantasyGenerator
    private let draw: () -> FantasyCreature
    var profile: FantasyProfile? { archive.profile }
    var introductionSeen: Bool { archive.introductionSeen ?? false }
    private(set) var availabilityMessage: String?
    func refreshAvailability() async { availabilityMessage = await generator.availabilityMessage() }
    func finishIntroduction() async throws {
        guard loaded, !busy else { throw AppFailure.busy }
        busy = true; defer { busy = false }
        var next = archive; next.introductionSeen = true
        try await repository.save(next); archive = next
    }
    var stories: [FantasyStory] { archive.stories }

    init(repository: any FantasyRepository, generator: any FantasyGenerator,
         draw: @escaping () -> FantasyCreature = { FantasyCreature.allCases.randomElement()! }) {
        self.repository = repository; self.generator = generator; self.draw = draw
    }
    func load() async throws {
        guard !loaded else { return }
        guard !busy else { throw AppFailure.busy }
        busy = true; defer { busy = false }
        archive = try await repository.load(); loaded = true
    }
    func drawCreature() async throws -> FantasyCreature {
        guard loaded, !busy else { throw AppFailure.busy }
        if let profile { return profile.creature }
        busy = true; defer { busy = false }
        let creature = draw()
        // Each creature has an equal share of the 1...999 reveal numbers.
        let count = FantasyCreature.allCases.count
        let number = creature.rawValue + count * Int.random(in: 0...((999 - creature.rawValue) / count))
        var next = archive; next.profile = FantasyProfile(creature: creature, revealNumber: number)
        try await repository.save(next); archive = next
        return creature
    }
    func saveDetails(name: String, biography: String) async throws {
        guard loaded, !busy else { throw AppFailure.busy }
        guard profile != nil else { throw AppFailure.unavailable("Reveal your creature first.") }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let biography = biography.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, !biography.isEmpty, biography.count <= 1200 else {
            throw AppFailure.unavailable("Enter your name (up to 80 characters) and a short biography (up to 1,200 characters).")
        }
        busy = true; defer { busy = false }
        var next = archive
        next.profile?.details = StorytellerDetails(name: name, biography: biography)
        try await repository.save(next); archive = next
    }
    func createIdentity(name: String, biography: String) async throws {
        guard loaded, !busy else { throw AppFailure.busy }
        guard let profile else { throw AppFailure.unavailable("Reveal your creature first.") }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let biography = biography.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, !biography.isEmpty, biography.count <= 1200 else {
            throw AppFailure.unavailable("Enter your name and a short biography of up to 1,200 characters.")
        }
        busy = true; defer { busy = false }
        let identity = try await generator.identity(name: name, biography: biography, creature: profile.creature)
        try Task.checkCancellation()
        try FantasyValidation.identity(identity)
        var next = archive; next.profile?.identity = identity
        try await repository.save(next); archive = next
    }
    func createStory(memory: String) async throws -> FantasyStory {
        guard loaded, !busy else { throw AppFailure.busy }
        guard let profile, profile.identity != nil else { throw AppFailure.unavailable("Create your storyteller first.") }
        let memory = memory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !memory.isEmpty, memory.count <= 3000 else { throw AppFailure.unavailable("Share a memory in up to 3,000 characters.") }
        busy = true; defer { busy = false }
        var story = try await generator.story(memory: memory, profile: profile)
        try Task.checkCancellation()
        try FantasyValidation.story(story)
        story.id = UUID()
        var next = archive; next.stories.append(story)
        try await repository.save(next); archive = next
        return story
    }
}
