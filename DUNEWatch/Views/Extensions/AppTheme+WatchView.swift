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
        case .desertWarm: DS.Color.warmGlow
        case .oceanCool:  Color("OceanAccent")
        }
    }

    /// Bronze/copper for hero text gradient start (Watch).
    var bronzeColor: Color {
        switch self {
        case .desertWarm: DS.Color.desertBronze
        case .oceanCool:  Color("OceanBronze")
        }
    }

    /// Cool secondary for gradient end (Watch).
    var duskColor: Color {
        switch self {
        case .desertWarm: DS.Color.desertDusk
        case .oceanCool:  Color("OceanDusk")
        }
    }

    /// Muted decorative text (Watch).
    var sandColor: Color {
        switch self {
        case .desertWarm: DS.Color.sandMuted
        case .oceanCool:  Color("OceanSand")
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
}

// MARK: - Metric Colors (Watch)

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

// MARK: - Display Name (Watch)

extension AppTheme {
    var displayName: String {
        switch self {
        case .desertWarm: "Desert Warm"
        case .oceanCool:  "Ocean Cool"
        }
    }
}
