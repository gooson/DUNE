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
            return String(format: "%.0fmin", value)
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
}
