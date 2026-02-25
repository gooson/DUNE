import Foundation

extension ExerciseRecord {
    /// Total training volume (weight × reps) from completed sets.
    var totalVolume: Double {
        (sets ?? []).reduce(0.0) { total, set in
            guard set.isCompleted else { return total }
            let weight = set.weight ?? 0
            let reps = Double(set.reps ?? 0)
            guard weight > 0, reps > 0 else { return total }
            return total + weight * reps
        }
    }
}
