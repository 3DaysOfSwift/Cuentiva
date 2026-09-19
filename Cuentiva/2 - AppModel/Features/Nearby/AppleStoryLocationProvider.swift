import CoreLocation
import MapKit
import Foundation

@MainActor final class AppleStoryLocationProvider: NSObject, StoryLocationProvider, CLLocationManagerDelegate {
    private var manager = CLLocationManager()
    private let request = LocationRequest()
    private var resolving = false
    private var geocoding: MKReverseGeocodingRequest?
    private var timeout: Task<Void, Never>?
    override init() {
        super.init(); manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    func currentLocation() async throws -> StoryLocation {
        try await request.value { token in
            // A fresh manager also isolates late delegate callbacks from an older request.
            manager.delegate = nil
            manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            resolving = false
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(25)) } catch { return }
                self?.request.finish(.failure(AppFailure.unavailable("Location took too long. Please try again outdoors.")), id: token)
            }
            requestIfAllowed()
        } stop: {
            self.timeout?.cancel(); self.timeout = nil
            self.geocoding?.cancel(); self.geocoding = nil
            self.manager.stopUpdatingLocation()
            self.manager.delegate = nil
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
        let source = ObjectIdentifier(manager)
        Task { @MainActor [weak self] in
            guard let self, ObjectIdentifier(self.manager) == source, self.request.id != nil else { return }
            self.requestIfAllowed()
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let source = ObjectIdentifier(manager)
        Task { @MainActor [weak self] in
            guard let self, ObjectIdentifier(self.manager) == source, self.request.id != nil else { return }
            self.resolve(locations)
        }
    }
    private func resolve(_ locations: [CLLocation]) {
        guard let point = locations.last, point.horizontalAccuracy >= 0,
              abs(point.timestamp.timeIntervalSinceNow) <= 60 else {
            finish(.failure(AppFailure.unavailable("A fresh location could not be found. Please try again."))); return
        }
        guard let token = request.id, !resolving else { return }
        resolving = true
        // Locality only: never display a street or accommodation address.
        guard let request = MKReverseGeocodingRequest(location: point) else {
            finish(.failure(AppFailure.unavailable("This location could not be resolved."))); return
        }
        geocoding = request
        request.getMapItems { [weak self] marks, _ in
            guard let self, self.request.id == token else { return }
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
        let source = ObjectIdentifier(manager)
        Task { @MainActor [weak self] in
            guard let self, ObjectIdentifier(self.manager) == source else { return }
            self.finish(.failure(AppFailure.unavailable(message)))
        }
    }
    private func finish(_ result: Result<StoryLocation, any Error>) {
        guard let token = request.id else { return }
        request.finish(result, id: token)
    }
}
