import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case train
    case wellness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .train: "Train"
        case .wellness: "Wellness"
        }
    }

    var icon: String {
        switch self {
        case .today: "heart.text.clipboard"
        case .train: "flame"
        case .wellness: "leaf.fill"
        }
    }
}
