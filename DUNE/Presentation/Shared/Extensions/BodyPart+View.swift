import SwiftUI

extension BodyPart {
    var displayName: String {
        switch self {
        case .neck: String(localized: "Neck")
        case .shoulder: String(localized: "Shoulder")
        case .elbow: String(localized: "Elbow")
        case .wrist: String(localized: "Wrist")
        case .lowerBack: String(localized: "Lower Back")
        case .hip: String(localized: "Hip")
        case .knee: String(localized: "Knee")
        case .ankle: String(localized: "Ankle")
        case .chest: String(localized: "Chest")
        case .upperBack: String(localized: "Upper Back")
        case .biceps: String(localized: "Biceps")
        case .triceps: String(localized: "Triceps")
        case .forearms: String(localized: "Forearms")
        case .core: String(localized: "Core")
        case .quadriceps: String(localized: "Quads")
        case .hamstrings: String(localized: "Hamstrings")
        case .glutes: String(localized: "Glutes")
        case .calves: String(localized: "Calves")
        }
    }

    var iconName: String {
        if isJoint {
            return "circle.circle.fill"
        }
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .upperBack: return "figure.rowing"
        case .biceps, .triceps, .forearms: return "dumbbell.fill"
        case .core: return "figure.core.training"
        case .quadriceps, .hamstrings, .glutes, .calves: return "figure.walk"
        default: return "figure.stand"
        }
    }
}

extension BodySide {
    var displayName: String {
        switch self {
        case .left: String(localized: "Left")
        case .right: String(localized: "Right")
        case .both: String(localized: "Both")
        }
    }

    var abbreviation: String {
        switch self {
        case .left: "L"
        case .right: "R"
        case .both: "LR"
        }
    }
}
