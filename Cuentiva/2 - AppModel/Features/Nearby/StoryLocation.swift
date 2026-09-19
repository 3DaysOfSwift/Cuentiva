import Foundation

/// Private submission evidence. Public UI shows only placeName, never coordinates.
/// A future server must keep these coordinates private and validate submission time.
struct StoryLocation: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let capturedAt: Date
    let placeName: String
    var valid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) &&
        (-180...180).contains(longitude) && accuracy.isFinite && accuracy >= 0 &&
        !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    func fresh(at now: Date = .now) -> Bool { valid && (-10...300).contains(now.timeIntervalSince(capturedAt)) }
    func kilometers(to other: StoryLocation) -> Double {
        let radians = Double.pi / 180
        let a = pow(sin((other.latitude - latitude) * radians / 2), 2) +
            cos(latitude * radians) * cos(other.latitude * radians) * pow(sin((other.longitude - longitude) * radians / 2), 2)
        return 6371 * 2 * asin(sqrt(min(1, max(0, a))))
    }
}

@MainActor protocol StoryLocationProvider: AnyObject {
    func currentLocation() async throws -> StoryLocation
}

/// Bridges one callback request into structured concurrency. Tokens prevent late
/// callbacks (including cancellation) from completing a subsequent request.
@MainActor final class LocationRequest {
    private var pending: CheckedContinuation<StoryLocation, any Error>?
    private var stop: (() -> Void)?
    private(set) var id: UUID?
    func value(start: (UUID) -> Void, stop: @escaping () -> Void) async throws -> StoryLocation {
        guard pending == nil else { throw AppFailure.busy }
        let token = UUID()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                id = token
                pending = continuation
                self.stop = stop
                start(token)
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError()), id: token) }
        }
    }
    func finish(_ result: Result<StoryLocation, any Error>, id token: UUID) {
        guard id == token else { return }
        let continuation = pending
        let cleanup = stop
        pending = nil; id = nil; stop = nil
        cleanup?()
        continuation?.resume(with: result)
    }
}
