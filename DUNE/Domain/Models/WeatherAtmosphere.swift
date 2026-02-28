import Foundation

/// Parameters for weather-reactive wave background rendering.
/// Presentation layer maps this to concrete SwiftUI colors/animations.
struct WeatherAtmosphere: Sendable, Hashable {
    let condition: WeatherConditionType
    let isDaytime: Bool
    let intensity: Double  // 0-1 (rain/snow intensity, wind speed fraction)

    static let `default` = WeatherAtmosphere(
        condition: .clear, isDaytime: true, intensity: 0
    )

    /// Creates an atmosphere from a weather snapshot.
    static func from(_ snapshot: WeatherSnapshot) -> WeatherAtmosphere {
        let intensity: Double
        switch snapshot.condition {
        case .heavyRain, .thunderstorm:
            intensity = 0.8
        case .rain, .sleet:
            intensity = 0.5
        case .snow:
            intensity = 0.4
        case .wind:
            intensity = Swift.min(1.0, snapshot.windSpeed / 80.0)
        case .fog, .haze:
            intensity = 0.3
        case .cloudy:
            intensity = 0.2
        case .partlyCloudy:
            intensity = 0.1
        case .clear:
            intensity = 0
        }

        return WeatherAtmosphere(
            condition: snapshot.condition,
            isDaytime: snapshot.isDaytime,
            intensity: intensity
        )
    }
}
