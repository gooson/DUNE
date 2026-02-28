import SwiftUI

// MARK: - HabitType Display

extension HabitType {
    var displayName: String {
        switch self {
        case .check:    String(localized: "Check")
        case .duration: String(localized: "Duration")
        case .count:    String(localized: "Count")
        }
    }

    var description: String {
        switch self {
        case .check:    String(localized: "Done or not done")
        case .duration: String(localized: "Track minutes spent")
        case .count:    String(localized: "Track number of times")
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
        case .health:      String(localized: "Health")
        case .fitness:     String(localized: "Fitness")
        case .study:       String(localized: "Study")
        case .coding:      String(localized: "Coding")
        case .mindfulness: String(localized: "Mindfulness")
        case .nutrition:   String(localized: "Nutrition")
        case .hydration:   String(localized: "Hydration")
        case .sleep:       String(localized: "Sleep")
        case .social:      String(localized: "Social")
        case .creative:    String(localized: "Creative")
        case .finance:     String(localized: "Finance")
        case .chores:      String(localized: "Chores")
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

    /// Theme-aware variant of `themeColor`.
    func themeColor(for theme: AppTheme) -> Color {
        switch self {
        case .health:      DS.Color.positive
        case .fitness:     DS.Color.activity
        case .study:       DS.Color.hrv
        case .coding:      DS.Color.rhr
        case .mindfulness: DS.Color.sleep
        case .nutrition:   theme.accentColor
        case .hydration:   DS.Color.tabWellness
        case .sleep:       DS.Color.sleep
        case .social:      DS.Color.activityDance
        case .creative:    DS.Color.activityMindBody
        case .finance:     theme.bronzeColor
        case .chores:      DS.Color.activityOther
        }
    }
}
