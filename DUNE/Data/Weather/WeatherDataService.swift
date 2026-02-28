import Foundation
import WeatherKit
import CoreLocation

/// Protocol for weather data fetching (testable).
protocol WeatherFetching: Sendable {
    func fetchWeather(for location: CLLocation) async throws -> WeatherSnapshot
}

/// High-level weather provider that handles location + weather in one call.
/// ViewModels depend on this protocol to avoid CoreLocation import.
protocol WeatherProviding: Sendable {
    func fetchCurrentWeather() async throws -> WeatherSnapshot
}

enum WeatherError: Error, Sendable {
    case locationNotAuthorized
}

/// Combines LocationService + WeatherDataService behind a single async call.
final class WeatherProvider: WeatherProviding, Sendable {
    private let locationService: LocationService
    private let weatherService: WeatherFetching

    init(
        locationService: LocationService,
        weatherService: WeatherFetching = WeatherDataService()
    ) {
        self.locationService = locationService
        self.weatherService = weatherService
    }

    func fetchCurrentWeather() async throws -> WeatherSnapshot {
        let authorized = await locationService.isAuthorized
        let denied = await locationService.isDenied

        if !authorized {
            if denied { throw WeatherError.locationNotAuthorized }
            // Permission not yet determined — request it.
            // The system dialog is async; this attempt will fail.
            // Next loadData() (after user grants) will succeed.
            await locationService.requestPermission()
            throw WeatherError.locationNotAuthorized
        }

        let location = try await locationService.requestLocation()
        return try await weatherService.fetchWeather(for: location)
    }
}

/// Fetches weather data from Apple WeatherKit with 15-minute caching.
final class WeatherDataService: WeatherFetching, Sendable {
    private let weatherService = WeatherService.shared
    private let cache = WeatherCache()

    func fetchWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        // Return cached if not stale
        if let cached = cache.get(), !cached.isStale {
            return cached
        }

        let (current, hourly) = try await weatherService.weather(
            for: location,
            including: .current, .hourly
        )

        let snapshot = mapToSnapshot(current: current, hourly: hourly)
        cache.set(snapshot)
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
                        temperature: clampTemperature(hour.temperature.converted(to: .celsius).value),
                        condition: mapCondition(hour.condition)
                    )
                }
        )

        return WeatherSnapshot(
            temperature: clampTemperature(current.temperature.converted(to: .celsius).value),
            feelsLike: clampTemperature(current.apparentTemperature.converted(to: .celsius).value),
            condition: mapCondition(current.condition),
            humidity: Swift.max(0, Swift.min(1, current.humidity)),
            uvIndex: Swift.max(0, Swift.min(15, current.uvIndex.value)),
            windSpeed: Swift.max(0, Swift.min(200, current.wind.speed.converted(to: .kilometersPerHour).value)),
            isDaytime: current.isDaylight,
            fetchedAt: Date(),
            hourlyForecast: hourlyItems
        )
    }

    /// Clamp temperature to physical range (-50°C to 60°C)
    private func clampTemperature(_ value: Double) -> Double {
        guard value.isFinite else { return 20 } // safe fallback
        return Swift.max(-50, Swift.min(60, value))
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
            return .clear
        }
    }
}
