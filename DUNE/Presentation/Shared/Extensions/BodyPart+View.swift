import SwiftUI

extension BodyPart {
    var displayName: String {
        switch self {
        case .neck: "Neck"
        case .shoulder: "Shoulder"
        case .elbow: "Elbow"
        case .wrist: "Wrist"
        case .lowerBack: "Lower Back"
        case .hip: "Hip"
        case .knee: "Knee"
        case .ankle: "Ankle"
        case .chest: "Chest"
        case .upperBack: "Upper Back"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .core: "Core"
        case .quadriceps: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .calves: "Calves"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .neck: "목"
        case .shoulder: "어깨"
        case .elbow: "팔꿈치"
        case .wrist: "손목"
        case .lowerBack: "허리"
        case .hip: "고관절"
        case .knee: "무릎"
        case .ankle: "발목"
        case .chest: "가슴"
        case .upperBack: "등"
        case .biceps: "이두"
        case .triceps: "삼두"
        case .forearms: "전완"
        case .core: "코어"
        case .quadriceps: "대퇴사두"
        case .hamstrings: "햄스트링"
        case .glutes: "둔근"
        case .calves: "종아리"
        }
    }

    var bilingualDisplayName: String {
        "\(displayName) (\(localizedDisplayName))"
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
        case .left: "Left"
        case .right: "Right"
        case .both: "Both"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .left: "왼쪽"
        case .right: "오른쪽"
        case .both: "양쪽"
        }
    }

    var bilingualDisplayName: String {
        "\(displayName) (\(localizedDisplayName))"
    }

    var abbreviation: String {
        switch self {
        case .left: "L"
        case .right: "R"
        case .both: "LR"
        }
    }
}
