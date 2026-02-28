import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case train
    case wellness
    case life

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .train: "Activity"
        case .wellness: "Wellness"
        case .life: "Life"
        }
    }

    var icon: String {
        switch self {
        case .today: "heart.text.clipboard"
        case .train: "flame"
        case .wellness: "leaf.fill"
        case .life: "checklist"
        }
    }
}
