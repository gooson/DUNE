import Foundation

enum WorkoutRecommendationContext: String, CaseIterable, Codable, Sendable {
    case gym
    case home

    var defaultEquipment: Set<Equipment> {
        switch self {
        case .gym:
            return Set(Equipment.allCases).subtracting([.other])
        case .home:
            return [
                .bodyweight,
                .dumbbell,
                .kettlebell,
                .band,
                .trx,
                .pullUpBar,
                .dipStation,
                .medicineBall,
                .stabilityBall,
            ]
        }
    }
}

struct WorkoutRecommendationConstraints: Sendable {
    let excludedExerciseIDs: Set<String>
    let allowedEquipment: Set<Equipment>?

    static let none = WorkoutRecommendationConstraints()

    init(
        excludedExerciseIDs: Set<String> = [],
        allowedEquipment: Set<Equipment>? = nil
    ) {
        self.excludedExerciseIDs = excludedExerciseIDs

        if let allowedEquipment {
            let sanitized = Set(allowedEquipment.filter { $0 != .other })
            self.allowedEquipment = sanitized.isEmpty ? nil : sanitized
        } else {
            self.allowedEquipment = nil
        }
    }

    func allows(_ exercise: ExerciseDefinition) -> Bool {
        if excludedExerciseIDs.contains(exercise.id) {
            return false
        }
        guard let allowedEquipment else {
            return true
        }
        return allowedEquipment.contains(exercise.equipment)
    }
}
