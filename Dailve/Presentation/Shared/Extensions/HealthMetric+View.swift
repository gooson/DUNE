import SwiftUI

extension HealthMetric {
    var formattedValue: String {
        switch category {
        case .hrv:
            return String(format: "%.0fms", value)
        case .rhr:
            return String(format: "%.0fbpm", value)
        case .sleep:
            return value.hoursMinutesFormatted
        case .exercise:
            // Per-type cards use their own unit (km, m, etc.)
            switch unit {
            case "km":  return String(format: "%.1fkm", value)
            case "m":   return String(format: "%.0fm", value)
            default:    return String(format: "%.0fmin", value)
            }
        case .steps:
            return String(format: "%.0f", value)
        case .weight:
            return String(format: "%.1fkg", value)
        }
    }

    var formattedChange: String? {
        guard let change else { return nil }
        let arrow = change > 0 ? "\u{25B2}" : "\u{25BC}"
        return "\(arrow)\(String(format: "%.1f", abs(change)))"
    }
}

extension HealthMetric {
    /// Resolved icon: uses iconOverride if set, otherwise falls back to category default.
    var resolvedIconName: String {
        iconOverride ?? category.iconName
    }
}

extension HealthMetric.Category {
    var themeColor: Color {
        switch self {
        case .hrv:      DS.Color.hrv
        case .rhr:      DS.Color.rhr
        case .sleep:    DS.Color.sleep
        case .exercise: DS.Color.activity
        case .steps:    DS.Color.steps
        case .weight:   DS.Color.body
        }
    }

    var iconName: String {
        switch self {
        case .hrv:      "waveform.path.ecg"
        case .rhr:      "heart.fill"
        case .sleep:    "moon.zzz.fill"
        case .exercise: "flame.fill"
        case .steps:    "figure.walk"
        case .weight:   "scalemass.fill"
        }
    }

    var displayName: String {
        switch self {
        case .hrv:      "Heart Rate Variability"
        case .rhr:      "Resting Heart Rate"
        case .sleep:    "Sleep"
        case .exercise: "Exercise"
        case .steps:    "Steps"
        case .weight:   "Weight"
        }
    }

    var unitLabel: String {
        switch self {
        case .hrv:      "ms"
        case .rhr:      "bpm"
        case .sleep:    ""
        case .exercise: "min"
        case .steps:    "steps"
        case .weight:   "kg"
        }
    }
}
