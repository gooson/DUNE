import CoreLocation
import Foundation

/// Protocol for weather data fetching (testable).
protocol WeatherFetching: Sendable {
    func fetchWeather(for location: CLLocation) async throws -> WeatherSnapshot
}

/// High-level weather provider that handles location + weather in one call.
/// ViewModels depend on this protocol to avoid CoreLocation import.
protocol WeatherProviding: Sendable {
    func fetchCurrentWeather() async throws -> WeatherSnapshot
    /// Request location permission from the user. Should be called from an explicit user action.
    func requestLocationPermission() async
    /// Whether location permission has been determined (denied or authorized).
    var isLocationPermissionDetermined: Bool { get async }
}

enum WeatherError: Error, Sendable {
    case locationNotAuthorized
    case locationRequestInFlight
    case locationTimeout
}

/// Combines LocationService + OpenMeteoService + AirQualityService behind a single async call.
/// Accepts WeatherFetching / AirQualityFetching dependencies for test injection.
final class WeatherProvider: WeatherProviding, Sendable {
    private let locationService: LocationService
    private let weatherService: WeatherFetching
    private let airQualityService: AirQualityFetching

    init(
        locationService: LocationService,
        weatherService: WeatherFetching = OpenMeteoService(),
        airQualityService: AirQualityFetching = OpenMeteoAirQualityService()
    ) {
        self.locationService = locationService
        self.weatherService = weatherService
        self.airQualityService = airQualityService
    }

    func fetchCurrentWeather() async throws -> WeatherSnapshot {
        let authorized = await locationService.isAuthorized

        guard authorized else {
            throw WeatherError.locationNotAuthorized
        }

        let location = try await locationService.requestLocation()

        // Parallel fetch: weather + air quality. Air quality failure is non-fatal.
        async let weatherTask = weatherService.fetchWeather(for: location)
        async let airQualityTask = safeAirQualityFetch(for: location)

        var snapshot = try await weatherTask
        let airQuality = await airQualityTask
        snapshot = snapshot.withAirQuality(airQuality)
        return snapshot
    }

    /// Air quality fetch with graceful failure — returns nil instead of throwing.
    /// CancellationError propagation: returns nil (parent is already cancelled).
    private func safeAirQualityFetch(for location: CLLocation) async -> AirQualitySnapshot? {
        do {
            return try await airQualityService.fetchAirQuality(for: location)
        } catch is CancellationError {
            return nil
        } catch {
            print("[WeatherProvider] Air quality fetch failed: \(error)")
            return nil
        }
    }

    func requestLocationPermission() async {
        await locationService.requestPermission()
    }

    var isLocationPermissionDetermined: Bool {
        get async {
            let status = await locationService.authorizationStatus
            return status != .notDetermined
        }
    }
}
