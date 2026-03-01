import SwiftUI

// MARK: - Environment Key

private struct WeatherAtmosphereKey: EnvironmentKey {
    static let defaultValue: WeatherAtmosphere = .default
}

extension EnvironmentValues {
    var weatherAtmosphere: WeatherAtmosphere {
        get { self[WeatherAtmosphereKey.self] }
        set { self[WeatherAtmosphereKey.self] = newValue }
    }
}

// MARK: - View Properties

extension WeatherAtmosphere {
    /// Wave color derived from weather condition and time of day (theme-aware).
    func waveColor(for theme: AppTheme) -> Color {
        if !isDaytime {
            return theme.weatherNightColor
        }
        return condition.waveColor(for: theme)
    }

    /// Legacy non-themed accessor (Desert Warm default).
    var waveColor: Color { waveColor(for: .desertWarm) }

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

    /// Gradient colors for the tab background overlay (theme-aware).
    func gradientColors(for theme: AppTheme) -> [Color] {
        let primary = waveColor(for: theme)
        if !isDaytime {
            return [
                primary.opacity(DS.Opacity.medium),
                theme.duskColor.opacity(DS.Opacity.subtle),
                .clear
            ]
        }
        return [
            primary.opacity(DS.Opacity.medium),
            theme.accentColor.opacity(DS.Opacity.subtle),
            .clear
        ]
    }

    /// Legacy non-themed accessor (Desert Warm default).
    var gradientColors: [Color] { gradientColors(for: .desertWarm) }
}
