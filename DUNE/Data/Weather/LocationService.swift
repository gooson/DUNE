import Foundation
import CoreLocation
@preconcurrency import MapKit
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

    /// Reverse-geocodes the given location into a locale-aware place name (e.g. "Seoul, South Korea").
    /// Returns cached result if location is within 1km and cache is fresh (< 60min).
    /// Returns nil on failure — callers should treat location name as optional.
    func reverseGeocode(_ location: CLLocation) async -> String? {
        if let cache = geocodeCache,
           cache.location.distance(from: location) < 1000,
           Date().timeIntervalSince(cache.cachedAt) < 60 * 60 {
            return cache.name
        }

        guard let request = MKReverseGeocodingRequest(location: location) else {
            geocodeCache = (location: location, name: nil, cachedAt: Date())
            return nil
        }
        do {
            let mapItems = try await request.mapItems
            let representations = mapItems.first?.addressRepresentations
            let name = representations?.cityWithContext ?? representations?.cityName
            geocodeCache = (location: location, name: name, cachedAt: Date())
            return name
        } catch {
            geocodeCache = (location: location, name: nil, cachedAt: Date())
            return nil
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
