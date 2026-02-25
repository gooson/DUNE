import SwiftUI

extension TrainingReadiness.Status {
    var label: String {
        switch self {
        case .ready:    "Ready to Train"
        case .moderate: "Moderate"
        case .light:    "Light Activity"
        case .rest:     "Rest Day"
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
        case .ready:    "Full intensity training recommended."
        case .moderate: "Normal training is fine."
        case .light:    "Reduce volume. Active recovery."
        case .rest:     "Rest or very light movement only."
        }
    }
}
