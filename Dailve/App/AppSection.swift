import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case exercise
    case sleep
    case body

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Today"
        case .exercise: "Activity"
        case .sleep: "Sleep"
        case .body: "Body"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "heart.text.clipboard"
        case .exercise: "flame"
        case .sleep: "moon.zzz"
        case .body: "figure.arms.open"
        }
    }
}
