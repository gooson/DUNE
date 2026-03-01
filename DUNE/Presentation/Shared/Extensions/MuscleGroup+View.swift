import SwiftUI

extension MuscleGroup {
    var displayName: String {
        switch self {
        case .chest: String(localized: "Chest")
        case .back: String(localized: "Back")
        case .shoulders: String(localized: "Shoulders")
        case .biceps: String(localized: "Biceps")
        case .triceps: String(localized: "Triceps")
        case .quadriceps: String(localized: "Quads")
        case .hamstrings: String(localized: "Hamstrings")
        case .glutes: String(localized: "Glutes")
        case .calves: String(localized: "Calves")
        case .core: String(localized: "Core")
        case .forearms: String(localized: "Forearms")
        case .traps: String(localized: "Traps")
        case .lats: String(localized: "Lats")
        }
    }

    var iconName: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rowing"
        case .shoulders: "figure.arms.open"
        case .biceps, .triceps, .forearms: "dumbbell.fill"
        case .quadriceps, .hamstrings, .glutes, .calves: "figure.walk"
        case .core: "figure.core.training"
        case .traps: "figure.arms.open"
        case .lats: "figure.rowing"
        }
    }
}
