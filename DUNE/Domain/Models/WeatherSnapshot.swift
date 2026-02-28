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

    struct HourlyWeather: Sendable, Hashable, Identifiable {
        var id: Date { hour }
        let hour: Date
        let temperature: Double
        let condition: WeatherConditionType
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
}
