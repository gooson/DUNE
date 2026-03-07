import Foundation

/// Data shared between the main app and the widget extension via an App Group file.
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

    enum CodingKeys: String, CodingKey {
        case conditionScore, conditionStatusRaw, conditionMessage
        case readinessScore, readinessStatusRaw, readinessMessage
        case wellnessScore, wellnessStatusRaw, wellnessMessage
        case updatedAt
    }

    static let userDefaultsKey = "com.raftel.dailve.widget_score_data"
    static let appGroupID = "group.com.raftel.dailve"
    static let fileName = "widget-score-data.json"

    static func sharedContainerURL(
        containerURLProvider: (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    ) -> URL? {
        containerURLProvider(appGroupID)
    }

    static func sharedFileURL(
        containerURLProvider: (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    ) -> URL? {
        sharedContainerURL(containerURLProvider: containerURLProvider)?
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
