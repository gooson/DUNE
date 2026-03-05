import SwiftUI

/// Widget-specific Design System subset. Uses shared Colors.xcassets.
enum WidgetDS {
    enum Color {
        static let scoreExcellent = SwiftUI.Color("ScoreExcellent")
        static let scoreGood      = SwiftUI.Color("ScoreGood")
        static let scoreFair      = SwiftUI.Color("ScoreFair")
        static let scoreTired     = SwiftUI.Color("ScoreTired")
        static let scoreWarning   = SwiftUI.Color("ScoreWarning")
        static let textSecondary  = SwiftUI.Color("TextSecondary")
        static let textTertiary   = SwiftUI.Color("TextTertiary")
        static let cardBackground = SwiftUI.Color("CardBackground")
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
}
