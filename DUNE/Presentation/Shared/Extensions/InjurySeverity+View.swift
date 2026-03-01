import SwiftUI

extension InjurySeverity {
    var displayName: String {
        switch self {
        case .minor: String(localized: "Minor")
        case .moderate: String(localized: "Moderate")
        case .severe: String(localized: "Severe")
        }
    }

    var color: Color {
        switch self {
        case .minor: .yellow
        case .moderate: .orange
        case .severe: .red
        }
    }

    var iconName: String {
        switch self {
        case .minor: "exclamationmark.circle"
        case .moderate: "exclamationmark.triangle"
        case .severe: "xmark.octagon.fill"
        }
    }

    var severityDescription: String {
        switch self {
        case .minor: String(localized: "Can exercise with caution")
        case .moderate: String(localized: "Avoid exercising the affected area")
        case .severe: String(localized: "Do not exercise the affected area")
        }
    }
}
