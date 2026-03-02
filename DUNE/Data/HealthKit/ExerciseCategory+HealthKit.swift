import Foundation
import HealthKit

/// Maps ExerciseCategory to HKWorkoutActivityType.
/// Kept in Data layer to avoid HealthKit import in Domain.
extension ExerciseCategory {

    /// Default HKWorkoutActivityType for this category.
    var hkWorkoutActivityType: HKWorkoutActivityType {
        switch self {
        case .strength:    .traditionalStrengthTraining
        case .cardio:      .other
        case .hiit:        .highIntensityIntervalTraining
        case .flexibility: .flexibility
        case .bodyweight:  .functionalStrengthTraining
        }
    }

    /// Resolve HKWorkoutActivityType using exercise name first, then category fallback.
    static func hkActivityType(category: ExerciseCategory, exerciseName: String) -> HKWorkoutActivityType {
        let normalized = exerciseName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case let n where n.contains("running") || n.contains("run")
            || n.contains("러닝") || n.contains("달리기") || n.contains("조깅"):
            return .running
        case let n where n.contains("walking") || n.contains("walk")
            || n.contains("걷기") || n.contains("워킹") || n.contains("산책"):
            return .walking
        case let n where n.contains("cycling") || n.contains("bike")
            || n.contains("사이클") || n.contains("사이클링") || n.contains("자전거"):
            return .cycling
        case let n where n.contains("swimming") || n.contains("swim")
            || n.contains("수영"):
            return .swimming
        case let n where n.contains("hiking") || n.contains("hike")
            || n.contains("하이킹") || n.contains("등산"):
            return .hiking
        case let n where n.contains("yoga") || n.contains("요가"):
            return .yoga
        case let n where n.contains("rowing") || n.contains("row")
            || n.contains("로잉"):
            return .rowing
        case let n where n.contains("elliptical")
            || n.contains("일립티컬") || n.contains("엘립티컬"):
            return .elliptical
        case let n where n.contains("pilates") || n.contains("필라테스"):
            return .pilates
        case let n where n.contains("dance") || n.contains("dancing")
            || n.contains("댄스") || n.contains("춤"):
            return .socialDance
        case let n where n.contains("core") || n.contains("코어"):
            return .coreTraining
        default: return category.hkWorkoutActivityType
        }
    }
}
