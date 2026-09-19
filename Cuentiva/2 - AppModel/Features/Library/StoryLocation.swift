import Foundation

/// Legacy content metadata retained for library and saved-draft compatibility.
/// The app no longer requests or browses the reader’s location.
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
}
