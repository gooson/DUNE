import Foundation

/// In-app navigation metadata attached to an alert item.
struct NotificationRoute: Codable, Sendable, Hashable {
    enum Destination: String, Codable, Sendable {
        case workoutDetail
    }

    let destination: Destination
    let workoutID: String?

    static func workoutDetail(workoutID: String) -> NotificationRoute? {
        guard !workoutID.isEmpty else { return nil }
        return NotificationRoute(destination: .workoutDetail, workoutID: workoutID)
    }
}

/// Persisted alert item shown in NotificationHubView.
struct NotificationInboxItem: Identifiable, Codable, Sendable, Equatable {
    enum Source: String, Codable, Sendable {
        case localNotification
    }

    let id: String
    let insightType: HealthInsight.InsightType
    let title: String
    let body: String
    let createdAt: Date
    var isRead: Bool
    var openedAt: Date?
    let route: NotificationRoute?
    let source: Source
}
