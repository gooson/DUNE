import Foundation

/// Bridges UNNotification userInfo dictionaries and typed notification data.
/// Shared between App layer (delegate) and Data layer (schedulers, inbox manager).
struct NotificationResponsePayload: Sendable, Equatable {
    private enum UserInfoKeys {
        static let itemID = "notificationItemID"
        static let routeKind = "notificationRouteKind"
        static let workoutID = "notificationWorkoutID"
        static let insightType = "notificationInsightType"
    }

    let itemID: String?
    let routeKind: String?
    let workoutID: String?
    let insightType: String?
    let title: String?
    let body: String?
    let date: Date?

    init(
        itemID: String? = nil,
        routeKind: String? = nil,
        workoutID: String? = nil,
        insightType: String? = nil,
        title: String? = nil,
        body: String? = nil,
        date: Date? = nil
    ) {
        self.itemID = itemID
        self.routeKind = routeKind
        self.workoutID = workoutID
        self.insightType = insightType
        self.title = title
        self.body = body
        self.date = date
    }

    init(userInfo: [AnyHashable: Any]) {
        self.init(
            itemID: userInfo[UserInfoKeys.itemID] as? String,
            routeKind: userInfo[UserInfoKeys.routeKind] as? String,
            workoutID: userInfo[UserInfoKeys.workoutID] as? String,
            insightType: userInfo[UserInfoKeys.insightType] as? String
        )
    }

    init(userInfo: [AnyHashable: Any], title: String?, body: String?, date: Date?) {
        self.init(
            itemID: userInfo[UserInfoKeys.itemID] as? String,
            routeKind: userInfo[UserInfoKeys.routeKind] as? String,
            workoutID: userInfo[UserInfoKeys.workoutID] as? String,
            insightType: userInfo[UserInfoKeys.insightType] as? String,
            title: title,
            body: body,
            date: date
        )
    }

    var userInfo: [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [:]
        if let itemID {
            userInfo[UserInfoKeys.itemID] = itemID
        }
        if let routeKind {
            userInfo[UserInfoKeys.routeKind] = routeKind
        }
        if let workoutID {
            userInfo[UserInfoKeys.workoutID] = workoutID
        }
        if let insightType {
            userInfo[UserInfoKeys.insightType] = insightType
        }
        return userInfo
    }
}
