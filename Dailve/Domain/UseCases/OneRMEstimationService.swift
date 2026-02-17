import Foundation

/// Supported 1RM estimation formulas
enum OneRMFormula: String, CaseIterable, Sendable {
    case epley = "Epley"
    case brzycki = "Brzycki"
    case lombardi = "Lombardi"

    /// Estimate 1RM from weight and reps
    /// - Parameters:
    ///   - weight: Weight lifted (kg), must be > 0
    ///   - reps: Number of reps performed, must be 1-30
    /// - Returns: Estimated 1RM in kg, or nil if inputs are invalid
    func estimate(weight: Double, reps: Int) -> Double? {
        guard weight > 0, reps >= 1, reps <= 30 else { return nil }

        // 1 rep = actual 1RM
        if reps == 1 { return weight }

        let r = Double(reps)
        let result: Double

        switch self {
        case .epley:
            // 1RM = w × (1 + r/30)
            result = weight * (1.0 + r / 30.0)
        case .brzycki:
            // 1RM = w × 36 / (37 - r)
            let denominator = 37.0 - r
            guard denominator > 0 else { return nil }
            result = weight * 36.0 / denominator
        case .lombardi:
            // 1RM = w × r^0.1
            let exponent = pow(r, 0.1)
            guard !exponent.isNaN && !exponent.isInfinite else { return nil }
            result = weight * exponent
        }

        guard !result.isNaN && !result.isInfinite && result > 0 else { return nil }
        return result
    }
}

/// Result of a 1RM estimation with context
struct OneRMEstimate: Sendable {
    let formula: OneRMFormula
    let estimatedMax: Double
    let basedOnWeight: Double
    let basedOnReps: Int
    let date: Date
}

/// 1RM analysis results for an exercise
struct OneRMAnalysis: Sendable {
    /// Best estimated 1RM across all sessions and formulas
    let currentBest: Double?
    /// Estimates from each formula for the best set
    let formulaComparison: [OneRMEstimate]
    /// 1RM history over time (for charting)
    let history: [OneRMHistoryPoint]
    /// Percentage zones based on best 1RM
    let trainingZones: [TrainingZone]
}

struct OneRMHistoryPoint: Sendable {
    let date: Date
    let epley: Double
    let brzycki: Double
    let lombardi: Double
    let average: Double
}

struct TrainingZone: Sendable {
    let name: String
    let percentage: ClosedRange<Double>
    let repsRange: String
    let weight: ClosedRange<Double>
}

/// Service for computing 1RM estimates and training zones
struct OneRMEstimationService: Sendable {

    /// Compute full 1RM analysis from workout session summaries (single-pass)
    func analyze(sessions: [OneRMSessionInput]) -> OneRMAnalysis {
        // Single-pass: find global best AND build history simultaneously
        var bestWeight: Double = 0
        var bestReps: Int = 0
        var bestDate = Date()
        var bestEpley: Double = 0
        var history: [OneRMHistoryPoint] = []

        for session in sessions {
            var sessionBestW: Double = 0
            var sessionBestR: Int = 0
            var sessionBestEpley: Double = 0

            for set in session.sets {
                guard let w = set.weight, w > 0, w <= 500,
                      let r = set.reps, r >= 1, r <= 30 else { continue }
                if let estimate = OneRMFormula.epley.estimate(weight: w, reps: r),
                   estimate > sessionBestEpley {
                    sessionBestEpley = estimate
                    sessionBestW = w
                    sessionBestR = r
                }
            }

            // Update global best
            if sessionBestEpley > bestEpley {
                bestEpley = sessionBestEpley
                bestWeight = sessionBestW
                bestReps = sessionBestR
                bestDate = session.date
            }

            // Build history point for this session
            if sessionBestEpley > 0 {
                let epley = sessionBestEpley
                let brzycki = OneRMFormula.brzycki.estimate(weight: sessionBestW, reps: sessionBestR) ?? epley
                let lombardi = OneRMFormula.lombardi.estimate(weight: sessionBestW, reps: sessionBestR) ?? epley
                let avg = (epley + brzycki + lombardi) / 3.0

                if !avg.isNaN && !avg.isInfinite {
                    history.append(OneRMHistoryPoint(
                        date: session.date,
                        epley: epley,
                        brzycki: brzycki,
                        lombardi: lombardi,
                        average: avg
                    ))
                }
            }
        }

        // Formula comparison for the best set
        var comparison: [OneRMEstimate] = []
        if bestEpley > 0 {
            for formula in OneRMFormula.allCases {
                if let estimate = formula.estimate(weight: bestWeight, reps: bestReps) {
                    comparison.append(OneRMEstimate(
                        formula: formula,
                        estimatedMax: estimate,
                        basedOnWeight: bestWeight,
                        basedOnReps: bestReps,
                        date: bestDate
                    ))
                }
            }
        }

        // Training zones based on best average 1RM
        let averageBest: Double? = comparison.isEmpty ? nil : {
            let sum = comparison.map(\.estimatedMax).reduce(0, +)
            let avg = sum / Double(comparison.count)
            return avg.isNaN || avg.isInfinite ? nil : avg
        }()

        let zones = makeTrainingZones(oneRM: averageBest)

        return OneRMAnalysis(
            currentBest: averageBest,
            formulaComparison: comparison,
            history: history,
            trainingZones: zones
        )
    }

    // MARK: - Training Zones

    private func makeTrainingZones(oneRM: Double?) -> [TrainingZone] {
        guard let max = oneRM, max > 0 else { return [] }

        return [
            TrainingZone(
                name: "Strength",
                percentage: 0.85...1.0,
                repsRange: "1-5",
                weight: (max * 0.85)...(max * 1.0)
            ),
            TrainingZone(
                name: "Hypertrophy",
                percentage: 0.67...0.85,
                repsRange: "6-12",
                weight: (max * 0.67)...(max * 0.85)
            ),
            TrainingZone(
                name: "Endurance",
                percentage: 0.50...0.67,
                repsRange: "12-20",
                weight: (max * 0.50)...(max * 0.67)
            ),
            TrainingZone(
                name: "Warm-up",
                percentage: 0.30...0.50,
                repsRange: "15-25",
                weight: (max * 0.30)...(max * 0.50)
            ),
        ]
    }
}

/// Input for 1RM analysis (avoids SwiftData dependency in Domain)
struct OneRMSessionInput: Sendable {
    let date: Date
    let sets: [OneRMSetInput]
}

struct OneRMSetInput: Sendable {
    let weight: Double?
    let reps: Int?
}
