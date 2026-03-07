import Foundation

enum WhatsNewArea: String, Codable, Hashable, Sendable {
    case today
    case activity
    case wellness
    case life
    case watch
    case settings

    var badgeTitle: String {
        switch self {
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
}

struct WhatsNewFeatureItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let titleKey: String
    let summaryKey: String
    let symbolName: String
    let area: WhatsNewArea

    var title: String {
        String(localized: String.LocalizationValue(titleKey))
    }

    var summary: String {
        String(localized: String.LocalizationValue(summaryKey))
    }

    var badgeTitle: String {
        area.badgeTitle
    }
}

struct WhatsNewReleaseData: Codable, Identifiable, Hashable, Sendable {
    let version: String
    let introKey: String
    let features: [WhatsNewFeatureItem]

    var id: String { version }

    var intro: String {
        String(localized: String.LocalizationValue(introKey))
    }
}

struct WhatsNewCatalog: Codable, Sendable {
    let releases: [WhatsNewReleaseData]
}
