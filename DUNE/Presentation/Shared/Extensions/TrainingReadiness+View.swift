import SwiftUI

extension TrainingReadiness.Status {
    var label: String {
        switch self {
        case .ready:    String(localized: "Ready to Train")
        case .moderate: String(localized: "Moderate")
        case .light:    String(localized: "Light Activity")
        case .rest:     String(localized: "Rest Day")
        }
    }

    var color: Color {
        switch self {
        case .ready:    DS.Color.scoreExcellent
        case .moderate: DS.Color.scoreGood
        case .light:    DS.Color.scoreFair
        case .rest:     DS.Color.scoreWarning
        }
    }

    var iconName: String {
        switch self {
        case .ready:    "flame.fill"
        case .moderate: "figure.walk"
        case .light:    "leaf.fill"
        case .rest:     "bed.double.fill"
        }
    }

    var guideMessage: String {
        switch self {
        case .ready:    String(localized: "Full intensity training recommended.")
        case .moderate: String(localized: "Normal training is fine.")
        case .light:    String(localized: "Reduce volume. Active recovery.")
        case .rest:     String(localized: "Rest or very light movement only.")
        }
    }
}
