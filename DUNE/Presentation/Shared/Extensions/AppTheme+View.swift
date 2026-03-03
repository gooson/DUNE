import SwiftUI

extension AppTheme {
    /// Prefix for themed assets.
    ///
    /// Desert is the default/base theme and uses unprefixed asset names.
    var assetPrefix: String? {
        switch self {
        case .desertWarm:
            nil
        case .oceanCool:
            "Ocean"
        case .forestGreen:
            "Forest"
        case .sakuraCalm:
            "Sakura"
        case .arcticDawn:
            "Arctic"
        }
    }

    /// Resolves an asset name using theme prefix conventions.
    ///
    /// - Parameters:
    ///   - defaultAsset: Asset name used by the default Desert theme.
    ///   - variantSuffix: Suffix appended to theme prefix for non-default themes.
    /// - Returns: Resolved asset name for the current theme.
    func themedAssetName(defaultAsset: String, variantSuffix: String) -> String {
        guard let prefix = assetPrefix else { return defaultAsset }
        return "\(prefix)\(variantSuffix)"
    }
}

private extension AppTheme {
    func themedColor(defaultAsset: String, variantSuffix: String) -> Color {
        Color(themedAssetName(defaultAsset: defaultAsset, variantSuffix: variantSuffix))
    }
}

// MARK: - Primary Accent & Brand Colors

extension AppTheme {
    /// Primary accent color (replaces warmGlow / OceanAccent / ForestAccent).
    var accentColor: Color {
        themedColor(defaultAsset: "AccentColor", variantSuffix: "Accent")
    }

    /// Bronze/copper for hero text gradient start.
    var bronzeColor: Color {
        themedColor(defaultAsset: "DesertBronze", variantSuffix: "Bronze")
    }

    /// Cool secondary for ring bottom, gradient end.
    var duskColor: Color {
        themedColor(defaultAsset: "DesertDusk", variantSuffix: "Dusk")
    }

    /// Muted decorative text.
    var sandColor: Color {
        themedColor(defaultAsset: "SandMuted", variantSuffix: "Sand")
    }
}

// MARK: - Tab Wave Colors

extension AppTheme {
    var tabTodayColor: Color { accentColor }

    var tabTrainColor: Color {
        themedColor(defaultAsset: "TabTrain", variantSuffix: "TabTrain")
    }

    var tabWellnessColor: Color {
        themedColor(defaultAsset: "TabWellness", variantSuffix: "TabWellness")
    }

    var tabLifeColor: Color {
        themedColor(defaultAsset: "TabLife", variantSuffix: "TabLife")
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

// MARK: - Arctic Wave-Specific Colors

extension AppTheme {
    /// Deep arctic haze layer (back).
    var arcticDeepColor: Color { Color("ArcticDeep") }

    /// Aurora ribbon glow layer (mid).
    var arcticAuroraColor: Color { Color("ArcticAurora") }

    /// Frost highlight layer (front).
    var arcticFrostColor: Color { Color("ArcticFrost") }
}

// MARK: - Score Colors

extension AppTheme {
    var scoreExcellent: Color {
        themedColor(defaultAsset: "ScoreExcellent", variantSuffix: "ScoreExcellent")
    }

    var scoreGood: Color {
        themedColor(defaultAsset: "ScoreGood", variantSuffix: "ScoreGood")
    }

    var scoreFair: Color {
        themedColor(defaultAsset: "ScoreFair", variantSuffix: "ScoreFair")
    }

    var scoreTired: Color {
        themedColor(defaultAsset: "ScoreTired", variantSuffix: "ScoreTired")
    }

    var scoreWarning: Color {
        themedColor(defaultAsset: "ScoreWarning", variantSuffix: "ScoreWarning")
    }
}

// MARK: - Metric Colors

extension AppTheme {
    var metricHRV: Color {
        themedColor(defaultAsset: "MetricHRV", variantSuffix: "MetricHRV")
    }

    var metricRHR: Color {
        themedColor(defaultAsset: "MetricRHR", variantSuffix: "MetricRHR")
    }

    var metricHeartRate: Color {
        themedColor(defaultAsset: "MetricHeartRate", variantSuffix: "MetricHeartRate")
    }

    var metricSleep: Color {
        themedColor(defaultAsset: "MetricSleep", variantSuffix: "MetricSleep")
    }

    var metricActivity: Color {
        themedColor(defaultAsset: "MetricActivity", variantSuffix: "MetricActivity")
    }

    var metricSteps: Color {
        themedColor(defaultAsset: "MetricSteps", variantSuffix: "MetricSteps")
    }

    var metricBody: Color {
        themedColor(defaultAsset: "MetricBody", variantSuffix: "MetricBody")
    }
}

// MARK: - Weather Colors (Theme-Aware)

extension AppTheme {
    var weatherClearColor: Color { accentColor }

    var weatherRainColor: Color {
        themedColor(defaultAsset: "WeatherRain", variantSuffix: "WeatherRain")
    }

    var weatherSnowColor: Color {
        themedColor(defaultAsset: "WeatherSnow", variantSuffix: "WeatherSnow")
    }

    var weatherCloudyColor: Color {
        themedColor(defaultAsset: "WeatherCloudy", variantSuffix: "WeatherCloudy")
    }

    var weatherNightColor: Color {
        themedColor(defaultAsset: "WeatherNight", variantSuffix: "WeatherNight")
    }

    var weatherWindColor: Color { sandColor }
}

#if os(iOS)
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
#endif

// MARK: - Card Surface

extension AppTheme {
    var cardBackground: Color {
        themedColor(defaultAsset: "CardBackground", variantSuffix: "CardBackground")
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
        case .arcticDawn:  String(localized: "Arctic Dawn")
        }
    }
}
