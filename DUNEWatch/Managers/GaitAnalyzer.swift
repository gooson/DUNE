import CoreMotion
import Foundation

// MARK: - Domain Models

/// Activity state detected by CMMotionActivityManager.
enum PostureActivityState: String, Sendable {
    case stationary
    case walking
    case running
    case unknown
}

/// Gait quality score computed from wrist motion during walking.
struct GaitQualityScore: Sendable, Equatable {
    /// Arm swing symmetry (0.0-1.0, higher = more symmetric).
    let symmetry: Double
    /// Step regularity (0.0-1.0, higher = more regular).
    let regularity: Double
    /// Overall score (0-100).
    let overall: Int

    static let zero = GaitQualityScore(symmetry: 0, regularity: 0, overall: 0)
}

/// Daily posture monitoring summary sent to iPhone.
struct DailyPostureSummary: Sendable, Codable, Equatable {
    let sedentaryMinutes: Int
    let standingMinutes: Int
    let walkingMinutes: Int
    let averageGaitScore: Int?
    let stretchRemindersTriggered: Int
    let date: Date
}

// MARK: - Gait Analyzer

/// Analyzes CMDeviceMotion samples collected during walking to produce a gait quality score.
///
/// Scoring approach:
/// - **Symmetry**: Compare positive vs negative pitch oscillation amplitudes.
///   Symmetric arm swing produces equal positive/negative peaks.
/// - **Regularity**: Measure consistency of vertical acceleration peak intervals.
///   Regular steps produce evenly spaced peaks.
enum GaitAnalyzer {
    /// Minimum number of samples required for analysis (~5 seconds at 50 Hz).
    static let minimumSampleCount = 250

    /// Analyze device motion samples and return a gait quality score.
    /// Returns `nil` if insufficient data.
    static func analyze(_ samples: [CMDeviceMotion]) -> GaitQualityScore? {
        guard samples.count >= minimumSampleCount else { return nil }

        let symmetry = computeSymmetry(samples)
        let regularity = computeRegularity(samples)

        guard symmetry.isFinite, regularity.isFinite else { return nil }

        let clampedSymmetry = max(0, min(1, symmetry))
        let clampedRegularity = max(0, min(1, regularity))
        let overall = Int((clampedSymmetry * 0.5 + clampedRegularity * 0.5) * 100)

        return GaitQualityScore(
            symmetry: clampedSymmetry,
            regularity: clampedRegularity,
            overall: max(0, min(100, overall))
        )
    }

    // MARK: - Symmetry

    /// Compute arm swing symmetry from pitch oscillation.
    /// Symmetric swing: |positive peaks| ≈ |negative peaks| → score ≈ 1.0.
    private static func computeSymmetry(_ samples: [CMDeviceMotion]) -> Double {
        let pitchValues = samples.map { $0.attitude.pitch }

        // Detrend: subtract mean
        let mean = pitchValues.reduce(0, +) / Double(pitchValues.count)
        let detrended = pitchValues.map { $0 - mean }

        // Sum of positive peaks and negative peaks
        var positiveSum = 0.0
        var negativeSum = 0.0

        for i in 1..<(detrended.count - 1) {
            let prev = detrended[i - 1]
            let curr = detrended[i]
            let next = detrended[i + 1]

            if curr > prev, curr > next, curr > 0.02 {
                positiveSum += curr
            } else if curr < prev, curr < next, curr < -0.02 {
                negativeSum += abs(curr)
            }
        }

        guard positiveSum > 0, negativeSum > 0 else { return 0 }

        // Ratio of smaller to larger → 1.0 means perfectly symmetric
        let ratio = min(positiveSum, negativeSum) / max(positiveSum, negativeSum)
        return ratio
    }

    // MARK: - Regularity

    /// Compute step regularity from vertical acceleration peak intervals.
    /// Regular steps: low coefficient of variation in peak-to-peak intervals → score ≈ 1.0.
    private static func computeRegularity(_ samples: [CMDeviceMotion]) -> Double {
        let yAccel = samples.map { $0.userAcceleration.y }

        // Detect positive peaks in vertical acceleration (step impacts)
        var peakIndices: [Int] = []
        let threshold = 0.15 // Minimum acceleration magnitude for a step

        for i in 1..<(yAccel.count - 1) {
            if yAccel[i] > yAccel[i - 1],
               yAccel[i] > yAccel[i + 1],
               yAccel[i] > threshold {
                peakIndices.append(i)
            }
        }

        // Need at least 4 peaks for meaningful interval analysis
        guard peakIndices.count >= 4 else { return 0 }

        // Compute intervals between consecutive peaks
        var intervals: [Int] = []
        for i in 1..<peakIndices.count {
            intervals.append(peakIndices[i] - peakIndices[i - 1])
        }

        guard !intervals.isEmpty else { return 0 }

        // Coefficient of variation: std / mean
        let meanInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
        guard meanInterval > 0 else { return 0 }

        let variance = intervals.map { pow(Double($0) - meanInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let std = sqrt(variance)
        let cv = std / meanInterval

        // Convert CV to score: CV=0 → 1.0, CV=0.5 → 0.0
        let score = max(0, 1.0 - cv * 2.0)
        return score
    }
}
