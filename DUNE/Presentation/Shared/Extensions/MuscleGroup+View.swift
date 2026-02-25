import SwiftUI

extension MuscleGroup {
    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .quadriceps: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .calves: "Calves"
        case .core: "Core"
        case .forearms: "Forearms"
        case .traps: "Traps"
        case .lats: "Lats"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .chest: "가슴"
        case .back: "등"
        case .shoulders: "어깨"
        case .biceps: "이두"
        case .triceps: "삼두"
        case .quadriceps: "대퇴사두"
        case .hamstrings: "햄스트링"
        case .glutes: "둔근"
        case .calves: "종아리"
        case .core: "코어"
        case .forearms: "전완"
        case .traps: "승모"
        case .lats: "광배"
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
