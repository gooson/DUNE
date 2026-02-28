import CoreLocation
import Foundation
import OSLog
import WeatherKit

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

/// Combines LocationService + WeatherDataService behind a single async call.
/// Falls back to OpenMeteoService when the primary WeatherKit service fails.
final class WeatherProvider: WeatherProviding, Sendable {
    private let locationService: LocationService
    private let weatherService: WeatherFetching
    private let fallbackService: WeatherFetching?

    init(
        locationService: LocationService,
        weatherService: WeatherFetching = WeatherDataService(),
        fallbackService: WeatherFetching? = OpenMeteoService()
    ) {
        self.locationService = locationService
        self.weatherService = weatherService
        self.fallbackService = fallbackService
    }

    func fetchCurrentWeather() async throws -> WeatherSnapshot {
        let authorized = await locationService.isAuthorized

        guard authorized else {
            throw WeatherError.locationNotAuthorized
        }

        let location = try await locationService.requestLocation()
        do {
            return try await weatherService.fetchWeather(for: location)
        } catch {
            guard let fallbackService else { throw error }
            AppLogger.data.info("[Weather] Primary failed (\(error.localizedDescription, privacy: .private)), trying fallback")
            return try await fallbackService.fetchWeather(for: location)
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

/// Fetches weather data from Apple WeatherKit with 15-minute caching.
/// Cache is inlined (single consumer) — no separate WeatherCache class needed.
final class WeatherDataService: WeatherFetching, @unchecked Sendable {
    private let weatherService = WeatherService.shared
    private var cached: WeatherSnapshot?
    private let lock = NSLock()

    func fetchWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        // Return cached if not stale (TTL enforced at read site)
        if let snapshot = lock.withLock({ cached }), !snapshot.isStale {
            return snapshot
        }

        let (current, hourly) = try await weatherService.weather(
            for: location,
            including: .current, .hourly
        )

        let snapshot = mapToSnapshot(current: current, hourly: hourly)
        lock.withLock { cached = snapshot }
        return snapshot
    }

    // MARK: - Mapping

    private func mapToSnapshot(
        current: CurrentWeather,
        hourly: Forecast<HourWeather>
    ) -> WeatherSnapshot {
        let hourlyItems = Array(
            hourly.forecast
                .prefix(6)
                .map { hour in
                    WeatherSnapshot.HourlyWeather(
                        hour: hour.date,
                        temperature: hour.temperature.converted(to: .celsius).value.clampedToPhysicalTemperature(),
                        condition: mapCondition(hour.condition)
                    )
                }
        )

        return WeatherSnapshot(
            temperature: current.temperature.converted(to: .celsius).value.clampedToPhysicalTemperature(),
            feelsLike: current.apparentTemperature.converted(to: .celsius).value.clampedToPhysicalTemperature(),
            condition: mapCondition(current.condition),
            humidity: Swift.max(0, Swift.min(1, current.humidity)),
            uvIndex: Swift.max(0, Swift.min(15, current.uvIndex.value)),
            windSpeed: Swift.max(0, Swift.min(200, current.wind.speed.converted(to: .kilometersPerHour).value)),
            isDaytime: current.isDaylight,
            fetchedAt: Date(),
            hourlyForecast: hourlyItems
        )
    }

    private func mapCondition(_ wkCondition: WeatherCondition) -> WeatherConditionType {
        switch wkCondition {
        case .clear, .mostlyClear, .hot:
            return .clear
        case .partlyCloudy:
            return .partlyCloudy
        case .mostlyCloudy, .cloudy:
            return .cloudy
        case .rain, .drizzle:
            return .rain
        case .heavyRain:
            return .heavyRain
        case .snow, .heavySnow, .flurries, .blizzard:
            return .snow
        case .sleet, .freezingRain, .freezingDrizzle, .wintryMix:
            return .sleet
        case .windy, .breezy:
            return .wind
        case .foggy:
            return .fog
        case .haze, .smoky:
            return .haze
        case .thunderstorms, .strongStorms, .tropicalStorm, .hurricane, .isolatedThunderstorms, .scatteredThunderstorms:
            return .thunderstorm
        case .blowingDust, .blowingSnow:
            return .wind
        case .frigid:
            return .snow
        case .hail:
            return .sleet
        case .sunFlurries, .sunShowers:
            return .partlyCloudy
        @unknown default:
            return .cloudy  // Conservative: unrecognized conditions should not trigger "favorable outdoor"
        }
    }
}
