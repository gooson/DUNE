import Foundation

/// Estimates per-set RPE from in-session data using %1RM mapping.
///
/// Uses the Epley formula to estimate 1RM from completed sets, then maps
/// the current set's weight as a percentage of estimated 1RM to an RPE value.
/// When reps degrade across sets (fatigue), adds +0.5 RPE correction.
///
/// Returns `nil` when estimation is not possible (no prior sets, bodyweight, etc.)
/// so the UI can silently skip RPE display.
struct WatchRPEEstimator: Sendable {

    /// Estimate RPE for the just-completed set based on in-session history.
    ///
    /// - Parameters:
    ///   - weight: Weight used for the completed set (kg).
    ///   - reps: Reps performed in the completed set.
    ///   - completedSets: All previously completed sets for the current exercise.
    /// - Returns: Estimated RPE (6.0–10.0, 0.5 step) or `nil` if estimation is not possible.
    func estimateRPE(weight: Double, reps: Int, completedSets: [CompletedSetData]) -> Double? {
        guard weight > 0, reps >= 1 else { return nil }

        // Need at least one prior set to estimate 1RM
        let validSets = completedSets.filter { ($0.weight ?? 0) > 0 && ($0.reps ?? 0) >= 1 }
        guard !validSets.isEmpty else { return nil }

        // Estimate 1RM from each prior set using Epley formula, take best
        let best1RM = validSets.compactMap { set -> Double? in
            guard let w = set.weight, w > 0, let r = set.reps, r >= 1 else { return nil }
            return epleyEstimate(weight: w, reps: r)
        }.max()

        guard let estimated1RM = best1RM, estimated1RM > 0 else { return nil }

        // Current set %1RM
        let percentageOf1RM = weight / estimated1RM

        // Map %1RM to base RPE
        var baseRPE = mapPercentageToRPE(percentageOf1RM)

        // Reps degradation correction: if reps decreased vs previous set, add +0.5
        if let lastSet = validSets.last,
           let lastReps = lastSet.reps,
           reps < lastReps {
            baseRPE += 0.5
        }

        // Validate and snap to 0.5 step within 6.0–10.0
        return RPELevel.validate(baseRPE)
    }

    // MARK: - Private

    /// Epley formula: 1RM = weight * (1 + reps/30)
    private func epleyEstimate(weight: Double, reps: Int) -> Double? {
        guard weight > 0, reps >= 1, reps <= 30 else { return nil }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Maps %1RM to base RPE value.
    private func mapPercentageToRPE(_ percentage: Double) -> Double {
        switch percentage {
        case 0.95...: 10.0
        case 0.90..<0.95: 9.0
        case 0.85..<0.90: 8.5
        case 0.80..<0.85: 7.5
        case 0.75..<0.80: 7.0
        case 0.70..<0.75: 6.5
        default: 6.0
        }
    }
}
