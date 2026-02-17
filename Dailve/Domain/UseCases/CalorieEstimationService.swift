import Foundation

protocol CalorieEstimating: Sendable {
    /// Estimate calories burned using MET formula.
    /// - Parameters:
    ///   - metValue: Metabolic Equivalent of Task for the exercise
    ///   - bodyWeightKg: User's body weight in kilograms
    ///   - durationSeconds: Total exercise duration in seconds
    ///   - restSeconds: Total rest time in seconds (subtracted from active time)
    /// - Returns: Estimated calories, or nil if inputs are invalid
    func estimate(
        metValue: Double,
        bodyWeightKg: Double,
        durationSeconds: TimeInterval,
        restSeconds: TimeInterval
    ) -> Double?
}

struct CalorieEstimationService: CalorieEstimating {
    static let defaultBodyWeightKg: Double = 70.0

    func estimate(
        metValue: Double,
        bodyWeightKg: Double,
        durationSeconds: TimeInterval,
        restSeconds: TimeInterval
    ) -> Double? {
        // Domain validation: MET 1-23 (sleep to sprinting uphill), weight 20-300kg, duration max 8h
        guard metValue > 0, metValue < 30,
              bodyWeightKg > 0, bodyWeightKg < 500,
              durationSeconds > 0, durationSeconds < 28800 else { return nil }

        let activeSeconds = max(durationSeconds - restSeconds, 0)
        guard activeSeconds > 0 else { return nil }

        let hours = activeSeconds / 3600.0
        let result = metValue * bodyWeightKg * hours

        guard !result.isNaN, !result.isInfinite, result >= 0 else { return nil }
        return result
    }
}
