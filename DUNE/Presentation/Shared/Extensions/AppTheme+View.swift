import SwiftUI

// MARK: - Primary Accent & Brand Colors

extension AppTheme {
    /// Primary accent color (replaces warmGlow / OceanAccent).
    var accentColor: Color {
        switch self {
        case .desertWarm: DS.Color.warmGlow
        case .oceanCool:  Color("OceanAccent")
        }
    }

    /// Bronze/copper for hero text gradient start (replaces desertBronze).
    var bronzeColor: Color {
        switch self {
        case .desertWarm: DS.Color.desertBronze
        case .oceanCool:  Color("OceanBronze")
        }
    }

    /// Cool secondary for ring bottom, gradient end (replaces desertDusk).
    var duskColor: Color {
        switch self {
        case .desertWarm: DS.Color.desertDusk
        case .oceanCool:  Color("OceanDusk")
        }
    }

    /// Muted decorative text (replaces sandMuted).
    var sandColor: Color {
        switch self {
        case .desertWarm: DS.Color.sandMuted
        case .oceanCool:  Color("OceanSand")
        }
    }
}

// MARK: - Tab Wave Colors

extension AppTheme {
    var tabTodayColor: Color {
        switch self {
        case .desertWarm: DS.Color.warmGlow
        case .oceanCool:  Color("OceanAccent")
        }
    }

    var tabTrainColor: Color {
        switch self {
        case .desertWarm: DS.Color.tabTrain
        case .oceanCool:  Color("OceanTabTrain")
        }
    }

    var tabWellnessColor: Color {
        switch self {
        case .desertWarm: DS.Color.tabWellness
        case .oceanCool:  Color("OceanTabWellness")
        }
    }

    var tabLifeColor: Color {
        switch self {
        case .desertWarm: DS.Color.tabLife
        case .oceanCool:  Color("OceanTabLife")
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
        case .desertWarm: DS.Color.scoreExcellent
        case .oceanCool:  Color("OceanScoreExcellent")
        }
    }

    var scoreGood: Color {
        switch self {
        case .desertWarm: DS.Color.scoreGood
        case .oceanCool:  Color("OceanScoreGood")
        }
    }

    var scoreFair: Color {
        switch self {
        case .desertWarm: DS.Color.scoreFair
        case .oceanCool:  Color("OceanScoreFair")
        }
    }

    var scoreTired: Color {
        switch self {
        case .desertWarm: DS.Color.scoreTired
        case .oceanCool:  Color("OceanScoreTired")
        }
    }

    var scoreWarning: Color {
        switch self {
        case .desertWarm: DS.Color.scoreWarning
        case .oceanCool:  Color("OceanScoreWarning")
        }
    }
}

// MARK: - Metric Colors

extension AppTheme {
    var metricHRV: Color {
        switch self {
        case .desertWarm: DS.Color.hrv
        case .oceanCool:  Color("OceanMetricHRV")
        }
    }

    var metricRHR: Color {
        switch self {
        case .desertWarm: DS.Color.rhr
        case .oceanCool:  Color("OceanMetricRHR")
        }
    }

    var metricHeartRate: Color {
        switch self {
        case .desertWarm: DS.Color.heartRate
        case .oceanCool:  Color("OceanMetricHeartRate")
        }
    }

    var metricSleep: Color {
        switch self {
        case .desertWarm: DS.Color.sleep
        case .oceanCool:  Color("OceanMetricSleep")
        }
    }

    var metricActivity: Color {
        switch self {
        case .desertWarm: DS.Color.activity
        case .oceanCool:  Color("OceanMetricActivity")
        }
    }

    var metricSteps: Color {
        switch self {
        case .desertWarm: DS.Color.steps
        case .oceanCool:  Color("OceanMetricSteps")
        }
    }

    var metricBody: Color {
        switch self {
        case .desertWarm: DS.Color.body
        case .oceanCool:  Color("OceanMetricBody")
        }
    }
}

// MARK: - Weather Colors (Theme-Aware)

extension AppTheme {
    var weatherClearColor: Color { accentColor }

    var weatherRainColor: Color {
        switch self {
        case .desertWarm: DS.Color.weatherRain
        case .oceanCool:  Color("OceanWeatherRain")
        }
    }

    var weatherSnowColor: Color {
        switch self {
        case .desertWarm: DS.Color.weatherSnow
        case .oceanCool:  Color("OceanWeatherSnow")
        }
    }

    var weatherCloudyColor: Color {
        switch self {
        case .desertWarm: DS.Color.weatherCloudy
        case .oceanCool:  Color("OceanWeatherCloudy")
        }
    }

    var weatherNightColor: Color {
        switch self {
        case .desertWarm: DS.Color.weatherNight
        case .oceanCool:  Color("OceanWeatherNight")
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
        case .desertWarm: DS.Color.cardBackground
        case .oceanCool:  Color("OceanCardBackground")
        }
    }
}

// MARK: - Display Name

extension AppTheme {
    var displayName: String {
        switch self {
        case .desertWarm: "Desert Warm"
        case .oceanCool:  "Ocean Cool"
        }
    }
}
