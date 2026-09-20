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
    static let maximumEditableReps = 100
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
}
