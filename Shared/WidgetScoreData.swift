import Foundation

/// Data shared between the main app and the widget extension via App Group UserDefaults.
struct WidgetScoreData: Codable, Sendable {
    var conditionScore: Int?
    var conditionStatusRaw: String?
    var conditionMessage: String?

    var readinessScore: Int?
    var readinessStatusRaw: String?
    var readinessMessage: String?

    var wellnessScore: Int?
    var wellnessStatusRaw: String?
    var wellnessMessage: String?

    var updatedAt: Date

    static let userDefaultsKey = "com.raftel.dailve.widget_score_data"
    static let appGroupID = "group.com.raftel.dailve"
}
