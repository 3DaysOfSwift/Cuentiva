import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct NearbyViewModelTests {
    @Test func leavingNearbyCancelsItsOwnedLocationTask() async throws {
        let provider = CancellableTestLocation()
        let viewModel = NearbyViewModel(feature: EmptyNearby(), provider: provider,
            progress: ProgressManager(repository: MemoryProgress()))
        viewModel.findStories()
        try await waitUntil { provider.request.id != nil }
        viewModel.clearLocation()
        try await waitUntil { provider.stopped }
        #expect(!viewModel.busy)
        #expect(viewModel.location == nil)
        #expect(viewModel.error == nil)
    }
}
