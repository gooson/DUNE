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
    /// HIIT: completed rounds percentile across history
    case roundsPercentile
    /// Flexibility/HIIT: user-provided manual intensity field
    case manualIntensity
    /// Fallback: only RPE was available
    case rpeOnly
}

// MARK: - Effort Category (Apple Fitness style)

/// 4-level effort classification aligned with Apple Fitness effort bands.
enum EffortCategory: Int, CaseIterable, Sendable, Comparable {
    case easy = 1      // Effort 1-3
    case moderate = 2  // Effort 4-6
    case hard = 3      // Effort 7-8
    case allOut = 4    // Effort 9-10

    init(effort: Int) {
        switch effort {
        case ...3: self = .easy
        case 4...6: self = .moderate
        case 7...8: self = .hard
        case 9...: self = .allOut
        }
    }

    static func < (lhs: EffortCategory, rhs: EffortCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Effort Suggestion

/// Auto-suggested effort with history context, returned by `suggestEffort()`.
struct EffortSuggestion: Sendable {
    /// Auto-suggested effort value (1-10).
    let suggestedEffort: Int
    /// Category derived from suggestedEffort.
    let category: EffortCategory
    /// Most recent user-entered effort for this exercise, or nil.
    let lastEffort: Int?
    /// Average effort from recent sessions (up to 5), or nil if insufficient data.
    let averageEffort: Double?
}
