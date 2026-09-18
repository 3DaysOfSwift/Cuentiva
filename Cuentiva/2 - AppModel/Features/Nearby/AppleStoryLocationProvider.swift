import CoreLocation
import MapKit
import Foundation

@MainActor final class AppleStoryLocationProvider: NSObject, StoryLocationProvider, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pending: CheckedContinuation<StoryLocation, any Error>?
    private var requestID = UUID()
    private var resolving = false
    private var geocoding: MKReverseGeocodingRequest?
    private var timeout: Task<Void, Never>?
    override init() {
        super.init(); manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    func currentLocation() async throws -> StoryLocation {
        guard pending == nil else { throw AppFailure.busy }
        return try await withCheckedThrowingContinuation { continuation in
            requestID = UUID(); resolving = false
            pending = continuation
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(25)) } catch { return }
                self?.finish(.failure(AppFailure.unavailable("Location took too long. Please try again outdoors.")))
            }
            requestIfAllowed()
        }
    }
    private func requestIfAllowed() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(AppFailure.unavailable("Location is unavailable. You can enable it in Settings or keep reading in Discover.")))
        @unknown default: finish(.failure(AppFailure.unavailable("Location is unavailable.")))
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in guard let self, self.pending != nil else { return }; self.requestIfAllowed() }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in self?.resolve(locations) }
    }
    private func resolve(_ locations: [CLLocation]) {
        guard let point = locations.last, point.horizontalAccuracy >= 0,
              abs(point.timestamp.timeIntervalSinceNow) <= 60 else {
            finish(.failure(AppFailure.unavailable("A fresh location could not be found. Please try again."))); return
        }
        guard pending != nil, !resolving else { return }
        resolving = true
        let token = requestID
        // Locality only: never display a street or accommodation address.
        guard let request = MKReverseGeocodingRequest(location: point) else {
            finish(.failure(AppFailure.unavailable("This location could not be resolved."))); return
        }
        geocoding = request
        request.getMapItems { [weak self] marks, _ in
            guard let self, self.requestID == token, self.pending != nil else { return }
            let name = marks?.first?.addressRepresentations?.cityWithContext(.full) ?? ""
            guard !name.isEmpty else {
                self.finish(.failure(AppFailure.unavailable("We could not identify this place. Please try again."))); return
            }
            self.finish(.success(StoryLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude,
                accuracy: point.horizontalAccuracy, capturedAt: point.timestamp, placeName: name)))
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in self?.finish(.failure(AppFailure.unavailable(message))) }
    }
    private func finish(_ result: Result<StoryLocation, any Error>) {
        timeout?.cancel(); timeout = nil
        geocoding?.cancel(); geocoding = nil
        let continuation = pending; pending = nil
        continuation?.resume(with: result)
    }
}
