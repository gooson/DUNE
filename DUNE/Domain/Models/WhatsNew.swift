import Foundation

enum WhatsNewArea: String, Hashable, Sendable {
    case today
    case activity
    case wellness
    case life
    case watch
}

enum WhatsNewDestination: String, Hashable, Sendable {
    case conditionScore
    case notificationHub
    case trainingReadiness
    case wellnessScore
    case activityOverview
    case lifeOverview
}

enum WhatsNewFeature: String, CaseIterable, Identifiable, Hashable, Sendable {
    case conditionScore
    case notifications
    case trainingReadiness
    case wellness
    case habits
    case watchQuickStart

    var id: String { rawValue }

    var area: WhatsNewArea {
        switch self {
        case .conditionScore, .notifications:
            .today
        case .trainingReadiness:
            .activity
        case .wellness:
            .wellness
        case .habits:
            .life
        case .watchQuickStart:
            .watch
        }
    }

    var destination: WhatsNewDestination? {
        switch self {
        case .conditionScore:
            .conditionScore
        case .notifications:
            .notificationHub
        case .trainingReadiness:
            .trainingReadiness
        case .wellness:
            .wellnessScore
        case .habits:
            .lifeOverview
        case .watchQuickStart:
            .activityOverview
        }
    }

    var title: String {
        switch self {
        case .conditionScore:
            String(localized: "Condition Score")
        case .notifications:
            String(localized: "Notifications")
        case .trainingReadiness:
            String(localized: "Training Readiness")
        case .wellness:
            String(localized: "Wellness")
        case .habits:
            String(localized: "My Habits")
        case .watchQuickStart:
            String(localized: "Quick Start")
        }
    }

    var summary: String {
        switch self {
        case .conditionScore:
            String(localized: "Check your condition score, coaching, and weather from the Today tab.")
        case .notifications:
            String(localized: "Review unread insights and jump back into important updates any time.")
        case .trainingReadiness:
            String(localized: "Open recovery details, weekly stats, and suggestions built around your recent training.")
        case .wellness:
            String(localized: "See sleep, body, and active indicators together in one score-driven view.")
        case .habits:
            String(localized: "Track daily habits and keep auto achievements moving with your routine.")
        case .watchQuickStart:
            String(localized: "Start workouts faster on Apple Watch and sync completed sessions back to iPhone.")
        }
    }

    var badgeTitle: String {
        switch area {
        case .today:
            "Today"
        case .activity:
            "Activity"
        case .wellness:
            "Wellness"
        case .life:
            "Life"
        case .watch:
            "Apple Watch"
        }
    }

    var imageAssetName: String {
        "whatsnew-\(rawValue)"
    }

    var symbolName: String {
        switch self {
        case .conditionScore:
            "heart.text.square.fill"
        case .notifications:
            "bell.badge.fill"
        case .trainingReadiness:
            "figure.strengthtraining.traditional"
        case .wellness:
            "leaf.fill"
        case .habits:
            "checklist.checked"
        case .watchQuickStart:
            "applewatch.watchface"
        }
    }
}

struct WhatsNewRelease: Identifiable, Hashable, Sendable {
    let version: String
    let intro: String
    let features: [WhatsNewFeature]

    var id: String { version }
}
