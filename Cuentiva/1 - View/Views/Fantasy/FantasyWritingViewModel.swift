import Foundation
import Observation

@MainActor @Observable final class FantasyWritingViewModel {
    private let feature: any FantasyFeature
    var memory = ""
    var story: FantasyStory?
    var busy = false
    var error: String?
    var showingProfile = false
    var publicationNotice: String?
    private(set) var nextPublicationDate: Date?
    var storyIsPublished: Bool { story.map { feature.publishedBook(for: $0) != nil } ?? false }
    func publish() async {
        guard !busy, let story else { return }
        busy = true; error = nil; publicationNotice = nil
        defer { busy = false; nextPublicationDate = feature.nextPublicationDate }
        do {
            _ = try await feature.publish(story)
            publicationNotice = "Published privately. Your book is now in Books under your storyteller’s name."
        } catch { self.error = error.localizedDescription }
    }
    var creature: FantasyCreature? { feature.profile?.creature }
    var needsProfile: Bool { feature.profile?.identity == nil }
    var availabilityMessage: String? { feature.availabilityMessage }
    func refreshAvailability() async {
        await feature.refreshAvailability()
        nextPublicationDate = feature.nextPublicationDate
    }
    init(feature: any FantasyFeature) { self.feature = feature }
    var stories: [FantasyStory] { feature.stories }
    func load() async {
        do { try await feature.load(); await refreshAvailability() } catch { self.error = error.localizedDescription }
    }
    func generate() async {
        guard !busy else { return }
        busy = true; error = nil; publicationNotice = nil; defer { busy = false }
        do { story = try await feature.createStory(memory: memory) }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
