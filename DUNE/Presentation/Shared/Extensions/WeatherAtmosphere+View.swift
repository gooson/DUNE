import SwiftUI

extension WeatherAtmosphere {
    /// Wave color derived from weather condition and time of day.
    var waveColor: Color {
        if !isDaytime {
            return DS.Color.weatherNight
        }
        return condition.waveColor
    }

    /// Wave amplitude varies with weather intensity.
    var waveAmplitude: CGFloat {
        switch condition {
        case .thunderstorm:             0.07
        case .heavyRain:                0.06
        case .rain, .sleet:             0.05
        case .wind:                     0.06
        case .snow:                     0.03
        case .fog, .haze:               0.03
        case .cloudy:                   0.04
        case .partlyCloudy, .clear:     0.04
        }
    }

    /// Wave frequency varies with weather dynamics.
    var waveFrequency: CGFloat {
        switch condition {
        case .thunderstorm:             3.5
        case .heavyRain:                3.0
        case .rain:                     2.5
        case .wind:                     3.5
        case .snow, .sleet:             1.5
        case .fog, .haze:               1.2
        case .cloudy:                   1.5
        case .partlyCloudy, .clear:     1.5
        }
    }

    /// Wave opacity varies with weather intensity.
    var waveOpacity: Double {
        switch condition {
        case .thunderstorm:             0.18
        case .heavyRain:                0.16
        case .rain, .sleet:             0.14
        case .wind:                     0.14
        case .snow:                     0.12
        case .fog, .haze:               0.10
        case .cloudy:                   0.12
        case .partlyCloudy, .clear:     0.12
        }
    }

    /// Gradient colors for the tab background overlay.
    var gradientColors: [Color] {
        let primary = waveColor
        if !isDaytime {
            return [
                primary.opacity(DS.Opacity.medium),
                DS.Color.desertDusk.opacity(DS.Opacity.subtle),
                .clear
            ]
        }
        return [
            primary.opacity(DS.Opacity.medium),
            DS.Color.warmGlow.opacity(DS.Opacity.subtle),
            .clear
        ]
    }
}
