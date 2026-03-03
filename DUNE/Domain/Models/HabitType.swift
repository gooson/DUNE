import Foundation

// MARK: - Habit Type

enum HabitType: String, Sendable, CaseIterable {
    case check    // Boolean: done or not
    case duration // Minutes spent
    case count    // Number of completions
}

// MARK: - Habit Frequency

enum HabitFrequency: Sendable, Equatable {
    case daily
    case weekly(targetDays: Int)
    case interval(days: Int)

    var isDaily: Bool {
        if case .daily = self { return true }
        return false
    }

    var weeklyTarget: Int? {
        if case .weekly(let days) = self { return days }
        return nil
    }

    var intervalDays: Int? {
        if case .interval(let days) = self {
            return Swift.max(1, days)
        }
        return nil
    }
}

// MARK: - Habit Icon Category

/// Fixed icon set per category — users pick a category, not individual SF Symbols.
enum HabitIconCategory: String, Sendable, CaseIterable {
    case health      // pill.fill
    case fitness     // figure.run
    case study       // book.fill
    case coding      // laptopcomputer
    case mindfulness // brain.head.profile
    case nutrition   // fork.knife
    case hydration   // drop.fill
    case sleep       // bed.double.fill
    case social      // person.2.fill
    case creative    // paintbrush.fill
    case finance     // banknote.fill
    case chores      // house.fill

    var iconName: String {
        switch self {
        case .health:      "pill.fill"
        case .fitness:     "figure.run"
        case .study:       "book.fill"
        case .coding:      "laptopcomputer"
        case .mindfulness: "brain.head.profile"
        case .nutrition:   "fork.knife"
        case .hydration:   "drop.fill"
        case .sleep:       "bed.double.fill"
        case .social:      "person.2.fill"
        case .creative:    "paintbrush.fill"
        case .finance:     "banknote.fill"
        case .chores:      "house.fill"
        }
    }
}

enum HabitCycleAction: String, Sendable, Equatable {
    case complete
    case skip
    case snooze
}

enum HabitRecurringStartPoint: String, Sendable, Equatable, CaseIterable {
    case createdAt
    case today
    case customDate
    case firstCompletion
}

// MARK: - Habit Progress

struct HabitProgress: Sendable, Identifiable {
    let id: UUID
    let name: String
    let iconCategory: HabitIconCategory
    let type: HabitType
    let goalValue: Double
    let goalUnit: String?
    let frequency: HabitFrequency
    let todayValue: Double
    let isCompleted: Bool
    let streak: Int
    let isAutoLinked: Bool
    let isAutoCompleted: Bool
    let isCycleBased: Bool
    let nextDueDate: Date?
    let cycleStartDate: Date?
    let cycleStartPoint: HabitRecurringStartPoint?
    let isScheduled: Bool
    let isDue: Bool
    let isOverdue: Bool
    let lastCycleAction: HabitCycleAction?
    let historyCount: Int
}
