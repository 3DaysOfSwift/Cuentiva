import Foundation
import Observation

@MainActor @Observable final class FantasyWritingViewModel {
    private let feature: any FantasyFeature
    var memory = ""
    var story: FantasyStory?
    var busy = false
    var error: String?
    var showingProfile = false
    var creature: FantasyCreature? { feature.profile?.creature }
    var needsProfile: Bool { feature.profile?.identity == nil }
    var availabilityMessage: String? { feature.availabilityMessage }
    func refreshAvailability() async { await feature.refreshAvailability() }
    init(feature: any FantasyFeature) { self.feature = feature }
    var stories: [FantasyStory] { feature.stories }
    func load() async {
        do { try await feature.load(); await feature.refreshAvailability() } catch { self.error = error.localizedDescription }
    }
    func generate() async {
        guard !busy else { return }
        busy = true; error = nil; defer { busy = false }
        do { story = try await feature.createStory(memory: memory) }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
