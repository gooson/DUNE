import SwiftUI

// MARK: - HabitType Display

extension HabitType {
    var displayName: String {
        switch self {
        case .check:    "Check"
        case .duration: "Duration"
        case .count:    "Count"
        }
    }

    var description: String {
        switch self {
        case .check:    "Done or not done"
        case .duration: "Track minutes spent"
        case .count:    "Track number of times"
        }
    }

    var iconName: String {
        switch self {
        case .check:    "checkmark.circle"
        case .duration: "clock"
        case .count:    "number"
        }
    }
}

// MARK: - HabitIconCategory Display

extension HabitIconCategory {
    var displayName: String {
        switch self {
        case .health:      "Health"
        case .fitness:     "Fitness"
        case .study:       "Study"
        case .coding:      "Coding"
        case .mindfulness: "Mindfulness"
        case .nutrition:   "Nutrition"
        case .hydration:   "Hydration"
        case .sleep:       "Sleep"
        case .social:      "Social"
        case .creative:    "Creative"
        case .finance:     "Finance"
        case .chores:      "Chores"
        }
    }

    var themeColor: Color {
        switch self {
        case .health:      DS.Color.positive
        case .fitness:     DS.Color.activity
        case .study:       DS.Color.hrv
        case .coding:      DS.Color.rhr
        case .mindfulness: DS.Color.sleep
        case .nutrition:   DS.Color.warmGlow
        case .hydration:   DS.Color.tabWellness
        case .sleep:       DS.Color.sleep
        case .social:      DS.Color.activityDance
        case .creative:    DS.Color.activityMindBody
        case .finance:     DS.Color.desertBronze
        case .chores:      DS.Color.activityOther
        }
    }
}
