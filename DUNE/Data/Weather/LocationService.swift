import Foundation
import CoreLocation
import Observation

/// Manages device location for weather data fetching.
/// Uses significant location change monitoring to minimize battery impact.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate, Sendable {
    private let manager = CLLocationManager()
    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private var locationContinuation: CheckedContinuation<CLLocation, any Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestPermission() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Requests a single location update. Returns cached location if fresh (< 60min).
    /// Throws if a request is already in flight (prevents continuation leak).
    /// Times out after 30 seconds to prevent indefinite hang in poor-signal environments.
    func requestLocation() async throws -> CLLocation {
        // Return cached if fresh enough (aligned with weather cache TTL)
        if let cached = currentLocation,
           Date().timeIntervalSince(cached.timestamp) < 60 * 60 {
            return cached
        }

        guard locationContinuation == nil else {
            throw WeatherError.locationRequestInFlight
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            self.manager.requestLocation()

            // Timeout after 30 seconds — @MainActor serializes access with delegate callbacks
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard let self, self.locationContinuation != nil else { return }
                self.locationContinuation?.resume(throwing: WeatherError.locationTimeout)
                self.locationContinuation = nil
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            currentLocation = location
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: any Error
    ) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
        }
    }
}
