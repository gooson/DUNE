import Foundation

/// Domain representation of current weather conditions.
/// Created by OpenMeteoService from Open-Meteo API data.
struct WeatherSnapshot: Sendable, Hashable {
    let temperature: Double        // celsius
    let feelsLike: Double          // celsius
    let condition: WeatherConditionType
    let humidity: Double           // 0-1
    let uvIndex: Int               // 0-15
    let windSpeed: Double          // km/h
    let isDaytime: Bool
    let fetchedAt: Date
    let hourlyForecast: [HourlyWeather]
    let dailyForecast: [DailyForecast]

    struct HourlyWeather: Sendable, Hashable, Identifiable {
        var id: Date { hour }
        let hour: Date
        let temperature: Double
        let condition: WeatherConditionType
        let feelsLike: Double
        let humidity: Double       // 0-1
        let uvIndex: Int
        let windSpeed: Double      // km/h
        let precipitationProbability: Int  // 0-100
    }

    struct DailyForecast: Sendable, Hashable, Identifiable {
        var id: Date { date }
        let date: Date
        let temperatureMax: Double
        let temperatureMin: Double
        let condition: WeatherConditionType
        let precipitationProbabilityMax: Int  // 0-100
        let uvIndexMax: Int
    }

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 60 * 60
    }

    /// Whether the feels-like temperature is extreme heat (35°C+)
    var isExtremeHeat: Bool { feelsLike >= 35 }

    /// Whether the feels-like temperature is freezing (0°C or below)
    var isFreezing: Bool { feelsLike <= 0 }

    /// Whether UV index is very high (8+)
    var isHighUV: Bool { uvIndex >= 8 }

    /// Whether humidity is uncomfortably high (80%+)
    var isHighHumidity: Bool { humidity >= 0.8 }

    /// Whether the weather is favorable for outdoor exercise
    var isFavorableOutdoor: Bool {
        !isExtremeHeat && !isFreezing && !isHighUV && !isHighHumidity
            && condition != .rain && condition != .heavyRain
            && condition != .snow && condition != .sleet
            && condition != .thunderstorm
            && windSpeed < 50
    }

    // MARK: - Outdoor Fitness Score

    /// Outdoor fitness score (0-100) for current conditions.
    var outdoorFitnessScore: Int {
        Self.calculateOutdoorScore(
            feelsLike: feelsLike,
            uvIndex: uvIndex,
            humidity: humidity,
            windSpeed: windSpeed,
            condition: condition
        )
    }

    /// Outdoor fitness level derived from score.
    var outdoorFitnessLevel: OutdoorFitnessLevel {
        OutdoorFitnessLevel(score: outdoorFitnessScore)
    }

    /// Best hour for outdoor exercise from hourly forecast.
    /// Returns nil if no hourly data available.
    var bestOutdoorHour: HourlyWeather? {
        guard !hourlyForecast.isEmpty else { return nil }
        return hourlyForecast.max { lhs, rhs in
            Self.calculateOutdoorScore(for: lhs) < Self.calculateOutdoorScore(for: rhs)
        }
    }

    /// Calculate outdoor score for an hourly forecast entry.
    static func calculateOutdoorScore(for hour: HourlyWeather) -> Int {
        calculateOutdoorScore(
            feelsLike: hour.feelsLike,
            uvIndex: hour.uvIndex,
            humidity: hour.humidity,
            windSpeed: hour.windSpeed,
            condition: hour.condition
        )
    }

    /// Core scoring algorithm: starts at 100, deducts based on conditions.
    static func calculateOutdoorScore(
        feelsLike: Double,
        uvIndex: Int,
        humidity: Double,
        windSpeed: Double,
        condition: WeatherConditionType
    ) -> Int {
        var score = 100

        // Temperature penalty: ideal 15-25°C (feels-like)
        if feelsLike < 15 {
            score -= Int((15 - feelsLike) * 3)
        } else if feelsLike > 25 {
            score -= Int((feelsLike - 25) * 3)
        }

        // UV penalty
        switch uvIndex {
        case 6...7:  score -= 5
        case 8...10: score -= 15
        case 11...:  score -= 25
        default:     break
        }

        // Humidity penalty: ideal 30-60% (humidity is 0-1)
        let humidityPercent = humidity * 100
        if humidityPercent < 30 {
            score -= Int((30 - humidityPercent) / 5) * 3
        } else if humidityPercent > 60 {
            score -= Int((humidityPercent - 60) / 5) * 3
        }

        // Wind penalty
        if windSpeed >= 40 {
            score -= 25
        } else if windSpeed >= 20 {
            score -= 10
        }

        // Precipitation/condition penalty
        switch condition {
        case .thunderstorm:          score -= 60
        case .heavyRain:             score -= 50
        case .snow, .sleet:          score -= 40
        case .rain:                  score -= 30
        case .fog:                   score -= 10
        case .haze:                  score -= 5
        case .wind:                  score -= 10
        case .clear, .partlyCloudy, .cloudy:
            break
        }

        return Swift.max(0, Swift.min(100, score))
    }
}

// MARK: - Outdoor Fitness Level

enum OutdoorFitnessLevel: Sendable, Hashable {
    case great    // 80-100
    case okay     // 60-79
    case caution  // 40-59
    case indoor   // 0-39

    init(score: Int) {
        switch score {
        case 80...100: self = .great
        case 60...79:  self = .okay
        case 40...59:  self = .caution
        default:       self = .indoor
        }
    }

    var displayName: String {
        switch self {
        case .great:   String(localized: "Great for outdoor exercise")
        case .okay:    String(localized: "Okay for outdoors")
        case .caution: String(localized: "Use caution outdoors")
        case .indoor:  String(localized: "Stay indoors")
        }
    }

    var shortDisplayName: String {
        switch self {
        case .great:   String(localized: "Great outdoors")
        case .okay:    String(localized: "Okay outdoors")
        case .caution: String(localized: "Caution")
        case .indoor:  String(localized: "Indoors")
        }
    }

    var systemImage: String {
        switch self {
        case .great:   "figure.run"
        case .okay:    "figure.walk"
        case .caution: "exclamationmark.triangle"
        case .indoor:  "house"
        }
    }
}
