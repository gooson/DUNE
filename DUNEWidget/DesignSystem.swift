import SwiftUI

/// Widget-specific Design System subset. Uses shared Colors.xcassets.
enum WidgetDS {
    static var isDesertWarm: Bool {
        let theme = WidgetScoreData.sharedDefaults()?.string(forKey: "com.raftel.dailve.app_theme")
        return theme == nil || theme == "desertWarm"
    }

    /// The main app mirrors its theme into the shared App Group for widget rendering.
    static var themeAccent: SwiftUI.Color {
        let rawValue = WidgetScoreData.sharedDefaults()?.string(forKey: "com.raftel.dailve.app_theme")
        let assetName: String
        switch rawValue {
        case "oceanCool": assetName = "OceanAccent"
        case "forestGreen": assetName = "ForestAccent"
        case "sakuraCalm": assetName = "SakuraAccent"
        case "arcticDawn", "articDawn", "artic": assetName = "ArcticAccent"
        case "solarPop": assetName = "SolarAccent"
        case "contourAtlas": assetName = "ContourAccent"
        case "waterLilies": assetName = "LilyAccent"
        default: assetName = "AccentColor"
        }
        return SwiftUI.Color(assetName)
    }

    enum Color {
        static let scoreExcellent = SwiftUI.Color("ScoreExcellent")
        static let scoreGood      = SwiftUI.Color("ScoreGood")
        static let scoreFair      = SwiftUI.Color("ScoreFair")
        static let scoreTired     = SwiftUI.Color("ScoreTired")
        static let scoreWarning   = SwiftUI.Color("ScoreWarning")
        static let textSecondary  = SwiftUI.Color("TextSecondary")
        static let textTertiary   = SwiftUI.Color("TextTertiary")
        static let cardBackground = SwiftUI.Color("CardBackground")
        static let warmSurface = SwiftUI.Color("WidgetWarmSurface")
        static let warmTile = SwiftUI.Color("WidgetWarmTile")
        static let warmStroke = SwiftUI.Color("WidgetWarmStroke")
        static let warmAccent = SwiftUI.Color("WidgetWarmAccent")
        static let warmInk = SwiftUI.Color("DesertHorizonInk")
        static var ringTrack: SwiftUI.Color { WidgetDS.themeAccent.opacity(0.12) }
        static var cardStroke: SwiftUI.Color {
            WidgetDS.isDesertWarm ? warmStroke : SwiftUI.Color.white.opacity(0.08)
        }
        static var placeholderFill: SwiftUI.Color { WidgetDS.themeAccent.opacity(0.06) }
    }

    enum Layout {
        static let edgePadding: CGFloat = 12
        static let headerSpacing: CGFloat = 8
        static let columnSpacing: CGFloat = 6
        static let rowSpacing: CGFloat = 6
        static let rowCornerRadius: CGFloat = 16
    }

    // MARK: - Status Color Mapping

    static func colorForConditionStatus(_ rawValue: String?) -> SwiftUI.Color {
        switch rawValue {
        case "excellent": Color.scoreExcellent
        case "good":      Color.scoreGood
        case "fair":      Color.scoreFair
        case "tired":     Color.scoreTired
        case "warning":   Color.scoreWarning
        default:          Color.textTertiary
        }
    }

    static func colorForReadinessStatus(_ rawValue: String?) -> SwiftUI.Color {
        switch rawValue {
        case "ready":    Color.scoreExcellent
        case "moderate": Color.scoreGood
        case "light":    Color.scoreFair
        case "rest":     Color.scoreWarning
        default:         Color.textTertiary
        }
    }

    static func colorForWellnessStatus(_ rawValue: String?) -> SwiftUI.Color {
        colorForConditionStatus(rawValue)
    }

    // MARK: - Status Icon Mapping

    static func iconForConditionStatus(_ rawValue: String?) -> String {
        switch rawValue {
        case "excellent": "checkmark.circle.fill"
        case "good":      "hand.thumbsup.fill"
        case "fair":      "minus.circle.fill"
        case "tired":     "moon.fill"
        case "warning":   "exclamationmark.triangle.fill"
        default:          "questionmark.circle"
        }
    }

    static func iconForReadinessStatus(_ rawValue: String?) -> String {
        switch rawValue {
        case "ready":    "flame.fill"
        case "moderate": "figure.walk"
        case "light":    "leaf.fill"
        case "rest":     "bed.double.fill"
        default:         "questionmark.circle"
        }
    }

    static func iconForWellnessStatus(_ rawValue: String?) -> String {
        iconForConditionStatus(rawValue)
    }

    // MARK: - Status Label Mapping

    static func labelForConditionStatus(_ rawValue: String?) -> String {
        switch rawValue {
        case "excellent": String(localized: "Excellent")
        case "good":      String(localized: "Good")
        case "fair":      String(localized: "Fair")
        case "tired":     String(localized: "Tired")
        case "warning":   String(localized: "Warning")
        default:          "—"
        }
    }

    static func labelForReadinessStatus(_ rawValue: String?) -> String {
        switch rawValue {
        case "ready":    String(localized: "Ready")
        case "moderate": String(localized: "Moderate")
        case "light":    String(localized: "Light")
        case "rest":     String(localized: "Rest")
        default:         "—"
        }
    }

    static func labelForWellnessStatus(_ rawValue: String?) -> String {
        labelForConditionStatus(rawValue)
    }

    static func ringGradient(for color: SwiftUI.Color) -> [SwiftUI.Color] {
        [
            color.opacity(0.24),
            color.opacity(0.92),
            color
        ]
    }
}

private struct WidgetSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        if WidgetDS.isDesertWarm {
            content.containerBackground(for: .widget) {
                WidgetDS.Color.warmSurface
            }
        } else {
            content.containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension View {
    func duneWidgetSurface() -> some View {
        modifier(WidgetSurfaceModifier())
    }
}
