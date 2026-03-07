import SwiftUI

extension WhatsNewArea {
    var badgeTitle: String {
        switch self {
        case .today: String(localized: "Today")
        case .activity: String(localized: "Activity")
        case .wellness: String(localized: "Wellness")
        case .life: String(localized: "Life")
        case .watch: String(localized: "Watch")
        case .settings: String(localized: "Settings")
        }
    }
}
