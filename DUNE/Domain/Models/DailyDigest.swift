import Foundation

/// AI-generated daily summary shown in the evening.
struct DailyDigest: Sendable, Identifiable {
    let id: UUID
    /// AI-generated 1-paragraph summary text.
    let summary: String
    let date: Date
    let metrics: DigestMetrics

    init(summary: String, date: Date = .now, metrics: DigestMetrics) {
        self.id = UUID()
        self.summary = summary
        self.date = date
        self.metrics = metrics
    }

    struct DigestMetrics: Sendable {
        let conditionScore: Int?
        let conditionDelta: Int?
        let workoutSummary: String?
        let sleepMinutes: Double?
        let sleepDebtMinutes: Double?
        let stepsCount: Int?
        let stressLevel: CumulativeStressScore.Level?
    }
}
