import Foundation

/// Weather condition classification for domain logic.
/// Mapped from WeatherKit's WeatherCondition in the Data layer.
enum WeatherConditionType: String, Sendable, Hashable, CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case rain
    case heavyRain
    case snow
    case sleet
    case wind
    case fog
    case haze
    case thunderstorm
}
