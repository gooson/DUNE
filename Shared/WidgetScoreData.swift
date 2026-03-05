import Foundation

/// Data shared between the main app and the widget extension via App Group UserDefaults.
struct WidgetScoreData: Codable, Sendable {
    let conditionScore: Int?
    let conditionStatusRaw: String?
    let conditionMessage: String?

    let readinessScore: Int?
    let readinessStatusRaw: String?
    let readinessMessage: String?

    let wellnessScore: Int?
    let wellnessStatusRaw: String?
    let wellnessMessage: String?

    let updatedAt: Date

    static let userDefaultsKey = "widget_score_data"
    static let appGroupID = "group.com.raftel.dailve"
}
