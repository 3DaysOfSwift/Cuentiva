import Foundation
import Observation

@MainActor @Observable final class NearbyViewModel {
    private let feature: any NearbyFeature
    private let provider: any StoryLocationProvider
    private let progress: any ProgressFeature
    private var generation = UUID()
    @ObservationIgnored private var locationTask: Task<Void, Never>?
    func findStories() {
        guard locationTask == nil else { return }
        locationTask = Task { await refresh() }
    }
    var location: StoryLocation?
    var radius = 1609.344
    var busy = false
    var error: String?
    var selectedBook: Book?
    var books: [Book] { guard let location else { return [] }; return feature.stories(around: location, kilometers: radius) }
    init(feature: any NearbyFeature = AppModel.shared.nearby,
         provider: any StoryLocationProvider = AppleStoryLocationProvider(),
         progress: any ProgressFeature = AppModel.shared.progress) {
        self.feature = feature; self.provider = provider; self.progress = progress
    }
    func completed(_ book: Book) -> Bool { progress.snapshot.completed.contains(book.id) }
    func refresh() async {
        guard !busy else { return }
        busy = true; error = nil; location = nil
        let token = generation
        defer {
            if token == generation { busy = false; locationTask = nil }
        }
        do {
            let value = try await provider.currentLocation()
            guard !Task.isCancelled, token == generation else { return }
            location = value
        } catch is CancellationError {
            // Leaving Nearby is not an error to display.
        } catch {
            if token == generation { self.error = error.localizedDescription }
        }
    }
    func clearLocation() {
        generation = UUID()
        locationTask?.cancel(); locationTask = nil
        location = nil; error = nil; busy = false
    }
}
