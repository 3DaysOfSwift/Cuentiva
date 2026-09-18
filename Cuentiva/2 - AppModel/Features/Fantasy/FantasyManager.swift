import Foundation
import Observation

@MainActor protocol FantasyFeature: PersonalLibraryFeature {
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
    var nextPublicationDate: Date? { get }
    func publishedBook(for story: FantasyStory) -> Book?
    func publish(_ story: FantasyStory) async throws -> Book
}

@MainActor @Observable final class FantasyManager: FantasyFeature {
    private var archive = FantasyArchive()
    private var loaded = false
    private var busy = false
    private let repository: any FantasyRepository
    private let generator: any FantasyGenerator
    private let draw: () -> FantasyCreature
    private let now: () -> Date
    private let calendar: Calendar
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
    var publishedBooks: [Book] {
        (archive.publications ?? []).sorted { $0.publishedAt > $1.publishedAt }.map { publication in
            var book = publication.book
            book.personalAuthor = personalAuthor ?? book.personalAuthor
            return book
        }
    }
    private var personalAuthor: Author? {
        guard let profile, let identity = profile.identity else { return nil }
        return Author(id: "personal-storyteller", name: identity.name,
                      portrait: profile.creature.portrait, introduction: identity.biography,
                      note: "Your own storyteller. These tales belong to your private library on this device.")
    }

    init(repository: any FantasyRepository, generator: any FantasyGenerator,
         draw: @escaping () -> FantasyCreature = { FantasyCreature.weightedDraw(ticket: Int.random(in: 1...10)) },
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.repository = repository; self.generator = generator; self.draw = draw
        self.now = now; self.calendar = calendar
    }
    var nextPublicationDate: Date? {
        guard let last = archive.publications?.map(\.publishedAt).max(),
              let next = calendar.date(byAdding: .day, value: 7, to: last), next > now() else { return nil }
        return next
    }
    func publishedBook(for story: FantasyStory) -> Book? {
        guard let publication = archive.publications?.first(where: { $0.storyID == story.id }) else { return nil }
        return publishedBooks.first { $0.id == publication.book.id }
    }
    func publish(_ story: FantasyStory) async throws -> Book {
        guard loaded, !busy else { throw AppFailure.busy }
        // Repeated taps and relaunches return the same book without using another week.
        if let existing = publishedBook(for: story) { return existing }
        if let nextDate = nextPublicationDate {
            throw AppFailure.unavailable("Your next personal book can be published on \(nextDate.formatted(date: .abbreviated, time: .shortened)).")
        }
        guard let saved = archive.stories.first(where: { $0.id == story.id }), let author = personalAuthor else {
            throw AppFailure.unavailable("Save your tale and storyteller before publishing.")
        }
        try FantasyValidation.story(saved)
        busy = true; defer { busy = false }
        let book = saved.personalBook(author: author)
        var next = archive
        if next.publications == nil { next.publications = [] }
        next.publications?.append(.init(storyID: saved.id, publishedAt: now(), book: book))
        try await repository.save(next)
        archive = next
        return book
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
        // Reveal numbers identify the chosen creature; the weighted draw above
        // gives foxes 80% of new profiles without changing existing avatars.
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
