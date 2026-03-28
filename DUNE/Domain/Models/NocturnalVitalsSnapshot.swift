import Foundation

/// Aggregated overnight vital signs aligned with the sleep window.
struct NocturnalVitalsSnapshot: Sendable {
    let sleepStart: Date
    let sleepEnd: Date

    /// 5-minute bucketed vital data.
    let heartRateBuckets: [VitalBucket]
    let respiratoryRateBuckets: [VitalBucket]
    let wristTemperatureBuckets: [VitalBucket]
    let spO2Buckets: [VitalBucket]

    /// Summary statistics for the entire sleep window.
    let summary: VitalsSummary

    struct VitalBucket: Sendable, Identifiable {
        /// Bucket start time (used as identity).
        let id: Date
        let avg: Double
        let min: Double
        let max: Double
    }

    struct VitalsSummary: Sendable {
        let minHeartRate: Double?
        let avgHeartRate: Double?
        let avgRespiratoryRate: Double?
        /// Deviation from recent baseline (°C). Positive = warmer than usual.
        let wristTempDeviation: Double?
        let avgSpO2: Double?
    }
}
