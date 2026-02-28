import Foundation

// MARK: - Intensity Level

/// 5-level workout intensity classification derived from raw score (0.0–1.0).
enum WorkoutIntensityLevel: Int, CaseIterable, Sendable, Comparable {
    case veryLight = 1
    case light = 2
    case moderate = 3
    case hard = 4
    case maxEffort = 5

    init(rawScore: Double) {
        switch rawScore {
        case ..<0.2: self = .veryLight
        case 0.2..<0.4: self = .light
        case 0.4..<0.6: self = .moderate
        case 0.6..<0.8: self = .hard
        default: self = .maxEffort
        }
    }

    static func < (lhs: WorkoutIntensityLevel, rhs: WorkoutIntensityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Intensity Result

/// Computed workout intensity with breakdown detail.
struct WorkoutIntensityResult: Sendable {
    let level: WorkoutIntensityLevel
    /// Normalized intensity score in 0.0–1.0 range.
    let rawScore: Double
    let detail: WorkoutIntensityDetail
}

/// Breakdown of signals that contributed to the intensity score.
struct WorkoutIntensityDetail: Sendable {
    /// Primary signal value (e.g. avg 1RM%, pace percentile). 0.0–1.0 or nil.
    let primarySignal: Double?
    /// Volume/duration signal relative to history. 0.0–1.0 or nil.
    let volumeSignal: Double?
    /// Normalized RPE (rpe / 10). 0.0–1.0 or nil.
    let rpeSignal: Double?
    /// Which calculation method was used.
    let method: IntensityMethod
}

/// Describes which formula was applied to compute intensity.
enum IntensityMethod: String, Sendable {
    /// Strength: working weight as % of estimated 1RM
    case oneRMBased
    /// Bodyweight: reps percentile across history
    case repsPercentile
    /// Cardio: pace percentile across history
    case pacePercentile
    /// Flexibility/HIIT: user-provided manual intensity field
    case manualIntensity
    /// Fallback: only RPE was available
    case rpeOnly
    /// Not enough data to compute any signal
    case insufficientData
}
