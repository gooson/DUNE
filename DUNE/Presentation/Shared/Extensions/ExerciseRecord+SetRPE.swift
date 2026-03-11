import Foundation

extension ExerciseRecord {
    /// Compute and apply session-level effort from per-set RPE values.
    /// Uses `WorkoutIntensityService.averageSetRPE` to map set RPE (6.0-10.0) to effort (1-10).
    /// Only sets `rpe` if at least one working set has a valid RPE value.
    func applySetBasedRPE(using service: WorkoutIntensityService = WorkoutIntensityService()) {
        let inputs = (sets ?? []).map {
            SetRPEInput(rpe: $0.rpe, setType: $0.setType)
        }
        if let effort = service.averageSetRPE(sets: inputs) {
            rpe = effort
        }
    }
}
