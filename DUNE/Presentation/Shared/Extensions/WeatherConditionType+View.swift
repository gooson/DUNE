import SwiftUI

extension WeatherConditionType {
    /// SF Symbol for this weather condition.
    var sfSymbol: String {
        switch self {
        case .clear:        "sun.max.fill"
        case .partlyCloudy: "cloud.sun.fill"
        case .cloudy:       "cloud.fill"
        case .rain:         "cloud.rain.fill"
        case .heavyRain:    "cloud.heavyrain.fill"
        case .snow:         "cloud.snow.fill"
        case .sleet:        "cloud.sleet.fill"
        case .wind:         "wind"
        case .fog:          "cloud.fog.fill"
        case .haze:         "sun.haze.fill"
        case .thunderstorm: "cloud.bolt.rain.fill"
        }
    }

    /// Localized label for this weather condition.
    var label: String {
        switch self {
        case .clear:        String(localized: "Clear")
        case .partlyCloudy: String(localized: "Partly Cloudy")
        case .cloudy:       String(localized: "Cloudy")
        case .rain:         String(localized: "Rain")
        case .heavyRain:    String(localized: "Heavy Rain")
        case .snow:         String(localized: "Snow")
        case .sleet:        String(localized: "Sleet")
        case .wind:         String(localized: "Wind")
        case .fog:          String(localized: "Fog")
        case .haze:         String(localized: "Haze")
        case .thunderstorm: String(localized: "Thunderstorm")
        }
    }

    /// Wave background color for this weather condition (theme-aware).
    func waveColor(for theme: AppTheme) -> Color {
        switch self {
        case .clear, .partlyCloudy:
            theme.weatherClearColor
        case .cloudy, .haze, .fog:
            theme.weatherCloudyColor
        case .rain, .heavyRain, .thunderstorm:
            theme.weatherRainColor
        case .snow, .sleet:
            theme.weatherSnowColor
        case .wind:
            theme.sandColor
        }
    }

    /// Legacy non-themed accessor (Desert Warm default).
    var waveColor: Color { waveColor(for: .desertWarm) }

    /// Icon tint color for weather card display (theme-aware).
    func iconColor(for theme: AppTheme) -> Color {
        switch self {
        case .clear:        theme.accentColor
        case .partlyCloudy: theme.bronzeColor
        case .cloudy:       theme.weatherCloudyColor
        case .rain:         theme.weatherRainColor
        case .heavyRain:    theme.weatherRainColor
        case .snow:         theme.weatherSnowColor
        case .sleet:        theme.weatherSnowColor
        case .wind:         theme.duskColor
        case .fog:          theme.weatherCloudyColor
        case .haze:         theme.sandColor
        case .thunderstorm: DS.Color.caution
        }
    }

    /// Legacy non-themed accessor (Desert Warm default).
    var iconColor: Color { iconColor(for: .desertWarm) }
}
