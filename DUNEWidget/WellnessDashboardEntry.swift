import WidgetKit

struct WellnessDashboardEntry: TimelineEntry {
    let date: Date

    let conditionScore: Int?
    let conditionStatusRaw: String?
    let conditionMessage: String?

    let readinessScore: Int?
    let readinessStatusRaw: String?
    let readinessMessage: String?

    let wellnessScore: Int?
    let wellnessStatusRaw: String?
    let wellnessMessage: String?

    /// When the scores were last computed by the main app.
    let scoreUpdatedAt: Date?

    var hasAnyScore: Bool {
        conditionScore != nil || readinessScore != nil || wellnessScore != nil
    }

    /// Status raw value for the lowest score (used in Small widget).
    var worstStatusRaw: String? {
        [(conditionScore, conditionStatusRaw),
         (readinessScore, readinessStatusRaw),
         (wellnessScore, wellnessStatusRaw)]
            .compactMap { score, raw in score.map { ($0, raw) } }
            .min { $0.0 < $1.0 }?.1
    }

    static let placeholder = WellnessDashboardEntry(
        date: .now,
        conditionScore: 78,
        conditionStatusRaw: "good",
        conditionMessage: "Solid recovery — HRV looks stable",
        readinessScore: 72,
        readinessStatusRaw: "moderate",
        readinessMessage: "Normal training is fine",
        wellnessScore: 65,
        wellnessStatusRaw: "good",
        wellnessMessage: "Good condition. Normal training is fine.",
        scoreUpdatedAt: .now
    )
}
