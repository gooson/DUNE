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
    private var geocodeCache: (location: CLLocation, name: String?, cachedAt: Date)?

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
           cached.horizontalAccuracy >= 0,
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

    // MARK: - Reverse Geocoding

    /// Reverse-geocodes the given location into a locale-aware place name (e.g. "Gangnam-gu, Seoul").
    /// Returns cached result if location is within 1km and cache is fresh (< 60min).
    /// Returns nil on failure — callers should treat location name as optional.
    func reverseGeocode(_ location: CLLocation) async -> String? {
        if let cache = geocodeCache,
           cache.location.distance(from: location) < 1000,
           Date().timeIntervalSince(cache.cachedAt) < 60 * 60 {
            return cache.name
        }

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let name = placemarks.first.flatMap {
                Self.formatPlaceName(subLocality: $0.subLocality, locality: $0.locality)
            }
            geocodeCache = (location: location, name: name, cachedAt: Date())
            return name
        } catch {
            return nil
        }
    }

    /// Formats place components into "subLocality, locality" (e.g. "Gangnam-gu, Seoul").
    /// Falls back to locality-only if subLocality is unavailable.
    nonisolated static func formatPlaceName(subLocality: String?, locality: String?) -> String? {
        let parts = [subLocality, locality].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
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
