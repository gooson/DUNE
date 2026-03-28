import Foundation

/// Result of correlating exercise patterns with subsequent sleep quality.
struct SleepExerciseCorrelation: Sendable {
    /// Number of matched (exercise day → next night sleep) data pairs.
    let dataPointCount: Int
    /// Confidence based on data availability.
    let confidence: Confidence
    /// Sleep stats broken down by exercise intensity band.
    let intensityBreakdown: [IntensityBand: SleepStats]
    /// Overall insight message, if sufficient data exists.
    let overallInsight: String?

    enum Confidence: String, Sendable {
        case low      // < 14 pairs
        case medium   // 14-30 pairs
        case high     // > 30 pairs
    }

    enum IntensityBand: String, Sendable, CaseIterable, Comparable {
        case rest     // intensity = 0
        case light    // intensity 0.01-0.39
        case moderate // intensity 0.40-0.69
        case intense  // intensity 0.70-1.0

        static func from(intensity: Double) -> IntensityBand {
            switch intensity {
            case ..<0.01: .rest
            case 0.01..<0.40: .light
            case 0.40..<0.70: .moderate
            default: .intense
            }
        }

        static func < (lhs: IntensityBand, rhs: IntensityBand) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }

        private var sortOrder: Int {
            switch self {
            case .rest: 0
            case .light: 1
            case .moderate: 2
            case .intense: 3
            }
        }

        var displayName: String {
            switch self {
            case .rest: String(localized: "Rest Day")
            case .light: String(localized: "Light")
            case .moderate: String(localized: "Moderate")
            case .intense: String(localized: "Intense")
            }
        }
    }

    struct SleepStats: Sendable {
        let avgScore: Double
        let avgDeepRatio: Double
        let avgEfficiency: Double
        let sampleCount: Int
    }
}
