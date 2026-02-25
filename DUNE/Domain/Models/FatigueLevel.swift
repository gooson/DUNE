import Foundation

/// 10-level muscle fatigue scale.
/// Level 0 = no data, Level 1 = fully recovered, Level 10 = overtrained.
enum FatigueLevel: Int, Sendable, CaseIterable, Comparable {
    case noData = 0
    case fullyRecovered = 1
    case wellRested = 2
    case lightFatigue = 3
    case mildFatigue = 4
    case moderateFatigue = 5
    case notableFatigue = 6
    case highFatigue = 7
    case veryHighFatigue = 8
    case extremeFatigue = 9
    case overtrained = 10

    static func < (lhs: FatigueLevel, rhs: FatigueLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Maps a normalized fatigue score (0.0 = fully recovered, 1.0 = overtrained) to a level.
    static func from(normalizedScore: Double) -> FatigueLevel {
        guard normalizedScore.isFinite else { return .fullyRecovered }
        let clamped = Swift.max(0, Swift.min(1, normalizedScore))
        switch clamped {
        case ..<0.05: return .fullyRecovered
        case 0.05..<0.15: return .wellRested
        case 0.15..<0.25: return .lightFatigue
        case 0.25..<0.35: return .mildFatigue
        case 0.35..<0.50: return .moderateFatigue
        case 0.50..<0.65: return .notableFatigue
        case 0.65..<0.75: return .highFatigue
        case 0.75..<0.85: return .veryHighFatigue
        case 0.85..<0.95: return .extremeFatigue
        default: return .overtrained
        }
    }

    /// Whether training is recommended at this fatigue level.
    var isTrainingRecommended: Bool { rawValue <= 4 }

    /// Whether active rest is advised.
    var isRestAdvised: Bool { rawValue >= 8 }
}
