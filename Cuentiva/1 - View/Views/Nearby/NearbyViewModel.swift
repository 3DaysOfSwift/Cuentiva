import Foundation
import Observation

@MainActor @Observable final class NearbyViewModel {
    private let feature: any NearbyFeature
    private let provider: any StoryLocationProvider
    private let progress: any ProgressFeature
    private var generation = UUID()
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
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        location = nil
        let token = generation
        do { let value = try await provider.currentLocation(); if token == generation { location = value } }
        catch { self.error = error.localizedDescription }
    }
    func clearLocation() { generation = UUID(); location = nil }
}
