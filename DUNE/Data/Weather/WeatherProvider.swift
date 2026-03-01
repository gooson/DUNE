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

/// Combines LocationService + OpenMeteoService behind a single async call.
/// Accepts a WeatherFetching dependency for test injection.
final class WeatherProvider: WeatherProviding, Sendable {
    private let locationService: LocationService
    private let weatherService: WeatherFetching

    init(
        locationService: LocationService,
        weatherService: WeatherFetching = OpenMeteoService()
    ) {
        self.locationService = locationService
        self.weatherService = weatherService
    }

    func fetchCurrentWeather() async throws -> WeatherSnapshot {
        let authorized = await locationService.isAuthorized

        guard authorized else {
            throw WeatherError.locationNotAuthorized
        }

        let location = try await locationService.requestLocation()

        // Parallel: weather fetch + reverse geocoding (independent)
        async let weatherTask = weatherService.fetchWeather(for: location)
        async let locationNameTask = locationService.reverseGeocode(location)

        let snapshot = try await weatherTask
        let locationName = await locationNameTask

        return snapshot.with(locationName: locationName)
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
