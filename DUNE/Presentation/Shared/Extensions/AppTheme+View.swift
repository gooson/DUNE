import SwiftUI

// MARK: - Primary Accent & Brand Colors

extension AppTheme {
    /// Primary accent color (replaces warmGlow / OceanAccent / ForestAccent).
    var accentColor: Color {
        switch self {
        case .desertWarm:  DS.Color.warmGlow
        case .oceanCool:   Color("OceanAccent")
        case .forestGreen: Color("ForestAccent")
        case .sakuraCalm: Color("SakuraAccent")
        }
    }

    /// Bronze/copper for hero text gradient start.
    var bronzeColor: Color {
        switch self {
        case .desertWarm:  DS.Color.desertBronze
        case .oceanCool:   Color("OceanBronze")
        case .forestGreen: Color("ForestBronze")
        case .sakuraCalm: Color("SakuraBronze")
        }
    }

    /// Cool secondary for ring bottom, gradient end.
    var duskColor: Color {
        switch self {
        case .desertWarm:  DS.Color.desertDusk
        case .oceanCool:   Color("OceanDusk")
        case .forestGreen: Color("ForestDusk")
        case .sakuraCalm: Color("SakuraDusk")
        }
    }

    /// Muted decorative text.
    var sandColor: Color {
        switch self {
        case .desertWarm:  DS.Color.sandMuted
        case .oceanCool:   Color("OceanSand")
        case .forestGreen: Color("ForestSand")
        case .sakuraCalm: Color("SakuraSand")
        }
    }
}

// MARK: - Tab Wave Colors

extension AppTheme {
    var tabTodayColor: Color {
        switch self {
        case .desertWarm:  DS.Color.warmGlow
        case .oceanCool:   Color("OceanAccent")
        case .forestGreen: Color("ForestAccent")
        case .sakuraCalm: Color("SakuraAccent")
        }
    }

    var tabTrainColor: Color {
        switch self {
        case .desertWarm:  DS.Color.tabTrain
        case .oceanCool:   Color("OceanTabTrain")
        case .forestGreen: Color("ForestTabTrain")
        case .sakuraCalm: Color("SakuraTabTrain")
        }
    }

    var tabWellnessColor: Color {
        switch self {
        case .desertWarm:  DS.Color.tabWellness
        case .oceanCool:   Color("OceanTabWellness")
        case .forestGreen: Color("ForestTabWellness")
        case .sakuraCalm: Color("SakuraTabWellness")
        }
    }

    var tabLifeColor: Color {
        switch self {
        case .desertWarm:  DS.Color.tabLife
        case .oceanCool:   Color("OceanTabLife")
        case .forestGreen: Color("ForestTabLife")
        case .sakuraCalm: Color("SakuraTabLife")
        }
    }
}

// MARK: - Gradients

extension AppTheme {
    /// Hero/metric value text gradient — Bronze → Accent horizontal blend.
    var heroTextGradient: LinearGradient {
        LinearGradient(
            colors: [bronzeColor, accentColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Detail view score text gradient — Bronze → Dusk vertical.
    var detailScoreGradient: LinearGradient {
        LinearGradient(
            colors: [bronzeColor, duskColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Section title accent bar gradient.
    var sectionAccentGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor.opacity(DS.Opacity.strong), duskColor.opacity(DS.Opacity.border)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Card background gradient — theme accent → clear.
    var cardBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor.opacity(DS.Opacity.subtle), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Ocean Wave-Specific Colors

extension AppTheme {
    /// Deepest ocean wave layer (back).
    var oceanDeepColor: Color { Color("OceanDeep") }

    /// Middle ocean wave layer.
    var oceanMidColor: Color { Color("OceanMid") }

    /// Surface ocean wave layer (front).
    var oceanSurfaceColor: Color { Color("OceanSurface") }

    /// Foam highlight on wave crests.
    var oceanFoamColor: Color { Color("OceanFoam") }

    /// Soft blue-gray mist.
    var oceanMistColor: Color { Color("OceanMist") }
}

// MARK: - Score Colors

extension AppTheme {
    var scoreExcellent: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreExcellent
        case .oceanCool:   Color("OceanScoreExcellent")
        case .forestGreen: Color("ForestScoreExcellent")
        case .sakuraCalm: Color("SakuraScoreExcellent")
        }
    }

    var scoreGood: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreGood
        case .oceanCool:   Color("OceanScoreGood")
        case .forestGreen: Color("ForestScoreGood")
        case .sakuraCalm: Color("SakuraScoreGood")
        }
    }

    var scoreFair: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreFair
        case .oceanCool:   Color("OceanScoreFair")
        case .forestGreen: Color("ForestScoreFair")
        case .sakuraCalm: Color("SakuraScoreFair")
        }
    }

    var scoreTired: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreTired
        case .oceanCool:   Color("OceanScoreTired")
        case .forestGreen: Color("ForestScoreTired")
        case .sakuraCalm: Color("SakuraScoreTired")
        }
    }

    var scoreWarning: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreWarning
        case .oceanCool:   Color("OceanScoreWarning")
        case .forestGreen: Color("ForestScoreWarning")
        case .sakuraCalm: Color("SakuraScoreWarning")
        }
    }
}

// MARK: - Metric Colors

extension AppTheme {
    var metricHRV: Color {
        switch self {
        case .desertWarm:  DS.Color.hrv
        case .oceanCool:   Color("OceanMetricHRV")
        case .forestGreen: Color("ForestMetricHRV")
        case .sakuraCalm: Color("SakuraMetricHRV")
        }
    }

    var metricRHR: Color {
        switch self {
        case .desertWarm:  DS.Color.rhr
        case .oceanCool:   Color("OceanMetricRHR")
        case .forestGreen: Color("ForestMetricRHR")
        case .sakuraCalm: Color("SakuraMetricRHR")
        }
    }

    var metricHeartRate: Color {
        switch self {
        case .desertWarm:  DS.Color.heartRate
        case .oceanCool:   Color("OceanMetricHeartRate")
        case .forestGreen: Color("ForestMetricHeartRate")
        case .sakuraCalm: Color("SakuraMetricHeartRate")
        }
    }

    var metricSleep: Color {
        switch self {
        case .desertWarm:  DS.Color.sleep
        case .oceanCool:   Color("OceanMetricSleep")
        case .forestGreen: Color("ForestMetricSleep")
        case .sakuraCalm: Color("SakuraMetricSleep")
        }
    }

    var metricActivity: Color {
        switch self {
        case .desertWarm:  DS.Color.activity
        case .oceanCool:   Color("OceanMetricActivity")
        case .forestGreen: Color("ForestMetricActivity")
        case .sakuraCalm: Color("SakuraMetricActivity")
        }
    }

    var metricSteps: Color {
        switch self {
        case .desertWarm:  DS.Color.steps
        case .oceanCool:   Color("OceanMetricSteps")
        case .forestGreen: Color("ForestMetricSteps")
        case .sakuraCalm: Color("SakuraMetricSteps")
        }
    }

    var metricBody: Color {
        switch self {
        case .desertWarm:  DS.Color.body
        case .oceanCool:   Color("OceanMetricBody")
        case .forestGreen: Color("ForestMetricBody")
        case .sakuraCalm: Color("SakuraMetricBody")
        }
    }
}

// MARK: - Weather Colors (Theme-Aware)

extension AppTheme {
    var weatherClearColor: Color { accentColor }

    var weatherRainColor: Color {
        switch self {
        case .desertWarm:  DS.Color.weatherRain
        case .oceanCool:   Color("OceanWeatherRain")
        case .forestGreen: Color("ForestWeatherRain")
        case .sakuraCalm: Color("SakuraWeatherRain")
        }
    }

    var weatherSnowColor: Color {
        switch self {
        case .desertWarm:  DS.Color.weatherSnow
        case .oceanCool:   Color("OceanWeatherSnow")
        case .forestGreen: Color("ForestWeatherSnow")
        case .sakuraCalm: Color("SakuraWeatherSnow")
        }
    }

    var weatherCloudyColor: Color {
        switch self {
        case .desertWarm:  DS.Color.weatherCloudy
        case .oceanCool:   Color("OceanWeatherCloudy")
        case .forestGreen: Color("ForestWeatherCloudy")
        case .sakuraCalm: Color("SakuraWeatherCloudy")
        }
    }

    var weatherNightColor: Color {
        switch self {
        case .desertWarm:  DS.Color.weatherNight
        case .oceanCool:   Color("OceanWeatherNight")
        case .forestGreen: Color("ForestWeatherNight")
        case .sakuraCalm: Color("SakuraWeatherNight")
        }
    }

    var weatherWindColor: Color { sandColor }
}

// MARK: - Outdoor Fitness Level Colors

extension AppTheme {
    func outdoorFitnessColor(for level: OutdoorFitnessLevel) -> Color {
        switch level {
        case .great:   scoreExcellent
        case .okay:    scoreGood
        case .caution: scoreTired
        case .indoor:  scoreWarning
        }
    }
}

// MARK: - Card Surface

extension AppTheme {
    var cardBackground: Color {
        switch self {
        case .desertWarm:  DS.Color.cardBackground
        case .oceanCool:   Color("OceanCardBackground")
        case .forestGreen: Color("ForestCardBackground")
        case .sakuraCalm: Color("SakuraCardBackground")
        }
    }
}

// MARK: - Display Name

extension AppTheme {
    var displayName: String {
        switch self {
        case .desertWarm:  String(localized: "Desert Warm")
        case .oceanCool:   String(localized: "Ocean Cool")
        case .forestGreen: String(localized: "Forest Green")
        case .sakuraCalm:  String(localized: "Sakura Calm")
        }
    }
}
