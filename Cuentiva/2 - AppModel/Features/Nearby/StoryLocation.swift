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
