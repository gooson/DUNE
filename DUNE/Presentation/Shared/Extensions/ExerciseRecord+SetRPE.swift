import Foundation

extension ExerciseRecord {
    /// Compute and apply session-level effort from per-set RPE values.
    /// Uses `WorkoutIntensityService.averageSetRPE` to map set RPE (6.0-10.0) to effort (1-10).
    /// Only sets `rpe` if at least one working set has a valid RPE value.
    func applySetBasedRPE(using service: WorkoutIntensityService = WorkoutIntensityService()) {
        // Preserve explicit and legacy session ratings; their provenance cannot be inferred.
        guard rpe == nil || effortSourceRaw == "setAverage" else { return }
        let inputs = completedSets.filter { $0.rpeSourceRaw != "estimated" }.map {
            SetRPEInput(rpe: $0.rpe, setType: $0.setType)
        }
        if let effort = service.averageSetRPE(sets: inputs) {
            rpe = effort
            effortSourceRaw = "setAverage"
        }
    }

    func applyUserEffort(_ effort: Int) {
        guard (1...10).contains(effort) else { return }
        rpe = effort
        effortSourceRaw = "user"
    }
}
