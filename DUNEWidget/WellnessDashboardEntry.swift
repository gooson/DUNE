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

    var hasAnyScore: Bool {
        conditionScore != nil || readinessScore != nil || wellnessScore != nil
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
        wellnessMessage: "Good condition. Normal training is fine."
    )
}
