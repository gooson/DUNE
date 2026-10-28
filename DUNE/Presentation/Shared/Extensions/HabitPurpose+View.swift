import SwiftUI

/// A presentation grouping. The persisted icon category remains unchanged.
enum HabitPurpose: String, CaseIterable, Identifiable, Sendable {
    case health
    case growth
    case mind
    case life

    var id: Self { self }

    var displayName: String {
        switch self {
        case .health: String(localized: "Body")
        case .growth: String(localized: "Growth")
        case .mind: String(localized: "Mind")
        case .life: String(localized: "Life")
        }
    }

    var iconName: String {
        switch self {
        case .health: "heart.fill"
        case .growth: "book.closed.fill"
        case .mind: "sparkles"
        case .life: "house.fill"
        }
    }
}

extension HabitIconCategory {
    var purpose: HabitPurpose {
        switch self {
        case .health, .fitness, .nutrition, .hydration, .sleep:
            .health
        case .study, .coding, .creative:
            .growth
        case .mindfulness, .social:
            .mind
        case .finance, .chores:
            .life
        }
    }
}
