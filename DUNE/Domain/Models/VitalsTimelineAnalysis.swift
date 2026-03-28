import Foundation

/// 30-day multi-vital timeline with anomaly detection.
struct VitalsTimelineAnalysis: Sendable {
    let heartRate: VitalTrack
    let respiratoryRate: VitalTrack
    let wristTemperature: VitalTrack
    let spO2: VitalTrack

    /// Days where any vital exceeded ±2σ threshold.
    let anomalyDays: [AnomalyDay]

    struct VitalTrack: Sendable {
        let dailySummaries: [DailySummary]
        let baseline: Double?
        let standardDeviation: Double?
        let hasData: Bool
    }

    struct DailySummary: Sendable, Identifiable {
        var id: Date { date }
        let date: Date
        let avg: Double
        let min: Double
        let max: Double
        let isAnomaly: Bool
    }

    struct AnomalyDay: Sendable, Identifiable {
        var id: Date { date }
        let date: Date
        let affectedVitals: [AffectedVital]
    }

    struct AffectedVital: Sendable {
        let type: VitalType
        let deviationSigma: Double
        let direction: Direction

        enum Direction: Sendable { case above, below }
    }

    enum VitalType: String, Sendable, CaseIterable {
        case heartRate
        case respiratoryRate
        case wristTemperature
        case spO2

        var displayName: String {
            switch self {
            case .heartRate: String(localized: "Heart Rate")
            case .respiratoryRate: String(localized: "Respiratory Rate")
            case .wristTemperature: String(localized: "Wrist Temp")
            case .spO2: String(localized: "SpO2")
            }
        }

        var unit: String {
            switch self {
            case .heartRate: "bpm"
            case .respiratoryRate: "brpm"
            case .wristTemperature: "°"
            case .spO2: "%"
            }
        }
    }
}
