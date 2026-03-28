import Foundation

/// Analysis of detected daytime naps over a period.
struct NapAnalysis: Sendable {
    /// Individual detected naps.
    let naps: [DetectedNap]

    /// Average nap duration in minutes (nil if no naps).
    let averageDurationMinutes: Double?

    /// Average nap frequency per week (nil if insufficient data).
    let frequencyPerWeek: Double?

    /// Number of days analyzed.
    let analysisDays: Int

    struct DetectedNap: Sendable, Identifiable {
        let id: UUID
        let startDate: Date
        let endDate: Date
        let durationMinutes: Double
    }
}
