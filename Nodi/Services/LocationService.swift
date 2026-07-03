import Foundation
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject {

    static let shared = LocationService()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestOneShotLocation() async throws -> CLLocation {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    /// Updates the signed-in user's `geohash`/`latitude`/`longitude` so
    /// Discovery's nearby-creatives query can find them. Called
    /// periodically (e.g. on app foreground) rather than continuously to
    /// avoid draining battery — Nodi is a networking app, not a
    /// turn-by-turn navigation app.
    func updateUserLocation(uid: String) async {
        guard let location = try? await requestOneShotLocation() else { return }
        let geohash = Geohash.encode(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        try? await UserRepository.shared.updateUser(uid: uid, fields: [
            "geohash": geohash,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude
        ])
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.continuation?.resume(returning: location)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }
}
