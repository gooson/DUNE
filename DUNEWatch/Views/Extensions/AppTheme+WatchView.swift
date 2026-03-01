import SwiftUI

// MARK: - Environment Key (Watch)

private struct WatchAppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .desertWarm
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[WatchAppThemeKey.self] }
        set { self[WatchAppThemeKey.self] = newValue }
    }
}

// MARK: - Primary Accent & Brand Colors (Watch)

extension AppTheme {
    /// Primary accent color (Watch).
    var accentColor: Color {
        switch self {
        case .desertWarm:  DS.Color.warmGlow
        case .oceanCool:   Color("OceanAccent")
        case .forestGreen: Color("ForestAccent")
        }
    }

    /// Bronze/copper for hero text gradient start (Watch).
    var bronzeColor: Color {
        switch self {
        case .desertWarm:  DS.Color.desertBronze
        case .oceanCool:   Color("OceanBronze")
        case .forestGreen: Color("ForestBronze")
        }
    }

    /// Cool secondary for gradient end (Watch).
    var duskColor: Color {
        switch self {
        case .desertWarm:  DS.Color.desertDusk
        case .oceanCool:   Color("OceanDusk")
        case .forestGreen: Color("ForestDusk")
        }
    }

    /// Muted decorative text (Watch).
    var sandColor: Color {
        switch self {
        case .desertWarm:  DS.Color.sandMuted
        case .oceanCool:   Color("OceanSand")
        case .forestGreen: Color("ForestSand")
        }
    }
}

// MARK: - Gradients (Watch)

extension AppTheme {
    /// Hero/metric value text gradient (Watch).
    var heroTextGradient: LinearGradient {
        LinearGradient(
            colors: [bronzeColor, accentColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Section title accent bar gradient (Watch).
    var sectionAccentGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor.opacity(DS.Opacity.strong), duskColor.opacity(DS.Opacity.border)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Card background gradient (Watch).
    var cardBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor.opacity(DS.Opacity.subtle), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Tab Wave Colors (Watch)

extension AppTheme {
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
}

// MARK: - Metric Colors (Watch)

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

// MARK: - Display Name (Watch)

extension AppTheme {
    var displayName: String {
        switch self {
        case .desertWarm:  String(localized: "Desert Warm")
        case .oceanCool:   String(localized: "Ocean Cool")
        case .forestGreen: String(localized: "Forest Green")
        }
    }
}
