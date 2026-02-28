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
        case .clear:        "맑음"
        case .partlyCloudy: "구름 조금"
        case .cloudy:       "흐림"
        case .rain:         "비"
        case .heavyRain:    "폭우"
        case .snow:         "눈"
        case .sleet:        "진눈깨비"
        case .wind:         "강풍"
        case .fog:          "안개"
        case .haze:         "연무"
        case .thunderstorm: "뇌우"
        }
    }

    /// Wave background color for this weather condition.
    var waveColor: Color {
        switch self {
        case .clear, .partlyCloudy:
            DS.Color.warmGlow
        case .cloudy, .haze, .fog:
            DS.Color.weatherCloudy
        case .rain, .heavyRain, .thunderstorm:
            DS.Color.weatherRain
        case .snow, .sleet:
            DS.Color.weatherSnow
        case .wind:
            DS.Color.sandMuted
        }
    }

    /// Icon tint color for weather card display.
    var iconColor: Color {
        switch self {
        case .clear:        DS.Color.warmGlow
        case .partlyCloudy: DS.Color.desertBronze
        case .cloudy:       DS.Color.weatherCloudy
        case .rain:         DS.Color.weatherRain
        case .heavyRain:    DS.Color.weatherRain
        case .snow:         DS.Color.weatherSnow
        case .sleet:        DS.Color.weatherSnow
        case .wind:         DS.Color.desertDusk
        case .fog:          DS.Color.weatherCloudy
        case .haze:         DS.Color.sandMuted
        case .thunderstorm: DS.Color.caution
        }
    }
}
