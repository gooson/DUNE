import Foundation

enum WhatsNewArea: String, Hashable, Sendable {
    case today
    case activity
    case wellness
    case life
    case watch
    case settings
}

enum WhatsNewFeature: String, CaseIterable, Identifiable, Hashable, Sendable {
    case widgets
    case conditionScore
    case weather
    case sleepDebt
    case notifications
    case muscleMap
    case trainingReadiness
    case wellness
    case habits
    case themes
    case watchQuickStart

    var id: String { rawValue }

    var area: WhatsNewArea {
        switch self {
        case .widgets, .conditionScore, .weather, .sleepDebt, .notifications:
            .today
        case .muscleMap, .trainingReadiness:
            .activity
        case .wellness:
            .wellness
        case .habits:
            .life
        case .themes:
            .settings
        case .watchQuickStart:
            .watch
        }
    }

    var title: String {
        switch self {
        case .widgets:
            String(localized: "Widgets")
        case .conditionScore:
            String(localized: "Condition Score")
        case .weather:
            String(localized: "Weather Guidance")
        case .sleepDebt:
            String(localized: "Sleep Debt")
        case .notifications:
            String(localized: "Notifications")
        case .muscleMap:
            String(localized: "Muscle Map")
        case .trainingReadiness:
            String(localized: "Training Readiness")
        case .wellness:
            String(localized: "Wellness")
        case .habits:
            String(localized: "My Habits")
        case .themes:
            String(localized: "Themes")
        case .watchQuickStart:
            String(localized: "Quick Start")
        }
    }

    var summary: String {
        switch self {
        case .widgets:
            String(localized: "Add DUNE widgets to your Home Screen and glance at your key scores without opening the app.")
        case .conditionScore:
            String(localized: "Check your condition score, coaching, and weather from the Today tab.")
        case .weather:
            String(localized: "Check live weather, outdoor fitness guidance, and hourly conditions before you head out.")
        case .sleepDebt:
            String(localized: "Spot your weekly sleep debt and open the sleep detail to compare recent rest against your baseline.")
        case .notifications:
            String(localized: "Review unread insights and jump back into important updates any time.")
        case .muscleMap:
            String(localized: "Open the muscle map to check which areas are recovered, overloaded, or ready for the next session.")
        case .trainingReadiness:
            String(localized: "Open recovery details, weekly stats, and suggestions built around your recent training.")
        case .wellness:
            String(localized: "See sleep, body, and active indicators together in one score-driven view.")
        case .habits:
            String(localized: "Track daily habits and keep auto achievements moving with your routine.")
        case .themes:
            String(localized: "Switch between eight visual themes from Settings and make the app feel more like yours.")
        case .watchQuickStart:
            String(localized: "Start workouts faster on Apple Watch and sync completed sessions back to iPhone.")
        }
    }

    var badgeTitle: String {
        switch area {
        case .today:
            String(localized: "Today")
        case .activity:
            String(localized: "Activity")
        case .wellness:
            String(localized: "Wellness")
        case .life:
            String(localized: "Life")
        case .watch:
            String(localized: "Apple Watch")
        case .settings:
            String(localized: "Appearance")
        }
    }

    var imageAssetName: String {
        "whatsnew-\(rawValue)"
    }

    var symbolName: String {
        switch self {
        case .widgets:
            "square.grid.2x2.fill"
        case .conditionScore:
            "heart.text.square.fill"
        case .weather:
            "cloud.sun.fill"
        case .sleepDebt:
            "moon.zzz.fill"
        case .notifications:
            "bell.badge.fill"
        case .muscleMap:
            "figure.stand"
        case .trainingReadiness:
            "figure.strengthtraining.traditional"
        case .wellness:
            "leaf.fill"
        case .habits:
            "checklist.checked"
        case .themes:
            "paintpalette.fill"
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
