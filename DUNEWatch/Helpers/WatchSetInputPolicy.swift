import Foundation

enum WatchSetInputPolicy {
    static func resolvedWeight(previousWeight: Double?, defaultWeight: Double?, hasPreviousSet: Bool) -> Double {
        // nil in a completed set means the user removed the load; do not restore the default.
        let candidate = hasPreviousSet ? previousWeight : defaultWeight
        guard let candidate, candidate.isFinite, (0...500).contains(candidate) else { return 0 }
        return candidate
    }

    static func completedWeight(_ weight: Double, inputType: ExerciseInputType) -> Double? {
        guard inputType == .setsRepsWeight || inputType == .setsReps,
              weight.isFinite, weight > 0, weight <= 500 else { return nil }
        return weight
    }
    static let defaultReps = 10
    static let minimumReps = 1
    static let maximumEditableReps = 1000
    static let maximumCompletionReps = 1000

    static func resolvedInitialReps(lastSetReps: Int?, entryDefaultReps: Int) -> Int {
        if let lastSetReps, (minimumReps...maximumCompletionReps).contains(lastSetReps) {
            return lastSetReps
        }
        if (minimumReps...maximumCompletionReps).contains(entryDefaultReps) {
            return entryDefaultReps
        }
        return defaultReps
    }

    static func isValidForCompletion(reps: Int) -> Bool {
        (minimumReps...maximumCompletionReps).contains(reps)
    }

    static func reducedWeight(
        after completed: CompletedSetData?,
        nextSetTypeRaw: String?,
        equipmentRaw: String?,
        progressionIncrementKg: Double? = nil,
        inputType: ExerciseInputType
    ) -> Double? {
        guard inputType == .setsRepsWeight || inputType == .setsReps,
              let completed,
              (nextSetTypeRaw.flatMap(SetType.init(rawValue:)) ?? .working) == .working else {
            return nil
        }
        let input = ProgressionSetInput(
            weight: completed.weight,
            reps: completed.reps,
            plannedReps: completed.plannedReps,
            rpe: completed.rpe,
            rpeSourceRaw: completed.rpeSourceRaw,
            setType: completed.setTypeRaw.flatMap(SetType.init(rawValue:)) ?? .working,
            isCompleted: true
        )
        let equipment = equipmentRaw.flatMap(Equipment.init(rawValue:)) ?? .other
        let fallbackIncrement = WorkoutProgressionService.incrementKg(equipment: equipment, primaryMuscles: [])
        let increment = progressionIncrementKg.flatMap { $0.isFinite && $0 > 0 && $0 <= 5 ? $0 : nil }
            ?? fallbackIncrement
        guard let recommendation = WorkoutProgressionService().nextSet(after: input, incrementKg: increment),
              recommendation.reason == .highEffort || recommendation.reason == .missedTarget,
              let previousWeight = completed.weight,
              recommendation.weight < previousWeight else { return nil }
        return recommendation.weight
    }
}
