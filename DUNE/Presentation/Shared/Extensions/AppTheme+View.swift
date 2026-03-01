import SwiftUI

// MARK: - Primary Accent & Brand Colors

extension AppTheme {
    /// Primary accent color (replaces warmGlow / OceanAccent / ForestAccent).
    var accentColor: Color {
        switch self {
        case .desertWarm:  DS.Color.warmGlow
        case .oceanCool:   Color("OceanAccent")
        case .forestGreen: Color("ForestAccent")
        }
    }

    /// Bronze/copper for hero text gradient start.
    var bronzeColor: Color {
        switch self {
        case .desertWarm:  DS.Color.desertBronze
        case .oceanCool:   Color("OceanBronze")
        case .forestGreen: Color("ForestBronze")
        }
    }

    /// Cool secondary for ring bottom, gradient end.
    var duskColor: Color {
        switch self {
        case .desertWarm:  DS.Color.desertDusk
        case .oceanCool:   Color("OceanDusk")
        case .forestGreen: Color("ForestDusk")
        }
    }

    /// Muted decorative text.
    var sandColor: Color {
        switch self {
        case .desertWarm:  DS.Color.sandMuted
        case .oceanCool:   Color("OceanSand")
        case .forestGreen: Color("ForestSand")
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
        }
    }

    var tabTrainColor: Color {
        switch self {
        case .desertWarm:  DS.Color.tabTrain
        case .oceanCool:   Color("OceanTabTrain")
        case .forestGreen: Color("ForestTabTrain")
        }
    }

    var tabWellnessColor: Color {
        switch self {
        case .desertWarm:  DS.Color.tabWellness
        case .oceanCool:   Color("OceanTabWellness")
        case .forestGreen: Color("ForestTabWellness")
        }
    }

    var tabLifeColor: Color {
        switch self {
        case .desertWarm:  DS.Color.tabLife
        case .oceanCool:   Color("OceanTabLife")
        case .forestGreen: Color("ForestTabLife")
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

// MARK: - Forest Wave-Specific Colors

extension AppTheme {
    /// Foreground forest layer (darkest green).
    var forestDeepColor: Color { Color("ForestDeep") }

    /// Middle forest layer.
    var forestMidColor: Color { Color("ForestMid") }

    /// Distant misty mountains.
    var forestMistColor: Color { Color("ForestMist") }

    /// Light/highlight (ukiyo-e paper cream).
    var forestFoamColor: Color { Color("ForestFoam") }
}

// MARK: - Score Colors

extension AppTheme {
    var scoreExcellent: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreExcellent
        case .oceanCool:   Color("OceanScoreExcellent")
        case .forestGreen: Color("ForestScoreExcellent")
        }
    }

    var scoreGood: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreGood
        case .oceanCool:   Color("OceanScoreGood")
        case .forestGreen: Color("ForestScoreGood")
        }
    }

    var scoreFair: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreFair
        case .oceanCool:   Color("OceanScoreFair")
        case .forestGreen: Color("ForestScoreFair")
        }
    }

    var scoreTired: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreTired
        case .oceanCool:   Color("OceanScoreTired")
        case .forestGreen: Color("ForestScoreTired")
        }
    }

    var scoreWarning: Color {
        switch self {
        case .desertWarm:  DS.Color.scoreWarning
        case .oceanCool:   Color("OceanScoreWarning")
        case .forestGreen: Color("ForestScoreWarning")
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
        }
    }

    var metricRHR: Color {
        switch self {
        case .desertWarm:  DS.Color.rhr
        case .oceanCool:   Color("OceanMetricRHR")
        case .forestGreen: Color("ForestMetricRHR")
        }
    }

    var metricHeartRate: Color {
        switch self {
        case .desertWarm:  DS.Color.heartRate
        case .oceanCool:   Color("OceanMetricHeartRate")
        case .forestGreen: Color("ForestMetricHeartRate")
        }
    }

    var metricSleep: Color {
        switch self {
        case .desertWarm:  DS.Color.sleep
        case .oceanCool:   Color("OceanMetricSleep")
        case .forestGreen: Color("ForestMetricSleep")
        }
    }

    var metricActivity: Color {
        switch self {
        case .desertWarm:  DS.Color.activity
        case .oceanCool:   Color("OceanMetricActivity")
        case .forestGreen: Color("ForestMetricActivity")
        }
    }

    var metricSteps: Color {
        switch self {
        case .desertWarm:  DS.Color.steps
        case .oceanCool:   Color("OceanMetricSteps")
        case .forestGreen: Color("ForestMetricSteps")
        }
    }

    var metricBody: Color {
        switch self {
        case .desertWarm:  DS.Color.body
        case .oceanCool:   Color("OceanMetricBody")
        case .forestGreen: Color("ForestMetricBody")
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
        }
    }

    var weatherSnowColor: Color {
        switch self {
        case .desertWarm:  DS.Color.weatherSnow
        case .oceanCool:   Color("OceanWeatherSnow")
        case .forestGreen: Color("ForestWeatherSnow")
        }
    }

    var weatherCloudyColor: Color {
        switch self {
        case .desertWarm:  DS.Color.weatherCloudy
        case .oceanCool:   Color("OceanWeatherCloudy")
        case .forestGreen: Color("ForestWeatherCloudy")
        }
    }

    var weatherNightColor: Color {
        switch self {
        case .desertWarm:  DS.Color.weatherNight
        case .oceanCool:   Color("OceanWeatherNight")
        case .forestGreen: Color("ForestWeatherNight")
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
        }
    }
}
