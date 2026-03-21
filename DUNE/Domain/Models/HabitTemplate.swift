import Foundation

// MARK: - Habit Template Category

enum HabitTemplateCategory: String, Sendable, CaseIterable {
    case health
    case fitness
    case productivity
    case mindfulness
    case lifestyle

    var displayName: String {
        switch self {
        case .health:       String(localized: "Health")
        case .fitness:      String(localized: "Fitness")
        case .productivity: String(localized: "Productivity")
        case .mindfulness:  String(localized: "Mindfulness")
        case .lifestyle:    String(localized: "Lifestyle")
        }
    }

    var iconName: String {
        switch self {
        case .health:       "heart.fill"
        case .fitness:      "figure.run"
        case .productivity: "briefcase.fill"
        case .mindfulness:  "brain.head.profile"
        case .lifestyle:    "house.fill"
        }
    }
}

// MARK: - Habit Template

struct HabitTemplate: Sendable, Identifiable {
    let id: String
    let nameKey: String
    let iconCategory: HabitIconCategory
    let type: HabitType
    let suggestedGoalValue: Double
    let suggestedGoalUnit: String?
    let suggestedFrequency: HabitFrequency
    let suggestedTimeOfDay: HabitTimeOfDay
    let category: HabitTemplateCategory

    var name: String {
        String(localized: String.LocalizationValue(nameKey))
    }
}

// MARK: - Predefined Templates

extension HabitTemplate {
    static let allTemplates: [HabitTemplate] = [
        // Health
        HabitTemplate(id: "water", nameKey: "Drink Water", iconCategory: .hydration, type: .count, suggestedGoalValue: 8, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .anytime, category: .health),
        HabitTemplate(id: "vitamins", nameKey: "Take Vitamins", iconCategory: .health, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .morning, category: .health),
        HabitTemplate(id: "sleep-early", nameKey: "Sleep Before Midnight", iconCategory: .sleep, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .evening, category: .health),
        HabitTemplate(id: "no-alcohol", nameKey: "No Alcohol", iconCategory: .health, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .evening, category: .health),

        // Fitness
        HabitTemplate(id: "workout", nameKey: "Workout", iconCategory: .fitness, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .weekly(targetDays: 5), suggestedTimeOfDay: .anytime, category: .fitness),
        HabitTemplate(id: "stretching", nameKey: "Stretching", iconCategory: .fitness, type: .duration, suggestedGoalValue: 10, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .morning, category: .fitness),
        HabitTemplate(id: "walk-10k", nameKey: "Walk 10,000 Steps", iconCategory: .fitness, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .anytime, category: .fitness),
        HabitTemplate(id: "running", nameKey: "Running", iconCategory: .fitness, type: .duration, suggestedGoalValue: 30, suggestedGoalUnit: nil, suggestedFrequency: .weekly(targetDays: 3), suggestedTimeOfDay: .morning, category: .fitness),

        // Productivity
        HabitTemplate(id: "reading", nameKey: "Reading", iconCategory: .study, type: .duration, suggestedGoalValue: 30, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .evening, category: .productivity),
        HabitTemplate(id: "coding", nameKey: "Coding Practice", iconCategory: .coding, type: .duration, suggestedGoalValue: 60, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .afternoon, category: .productivity),
        HabitTemplate(id: "journal", nameKey: "Write Journal", iconCategory: .creative, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .evening, category: .productivity),
        HabitTemplate(id: "language", nameKey: "Language Study", iconCategory: .study, type: .duration, suggestedGoalValue: 20, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .morning, category: .productivity),

        // Mindfulness
        HabitTemplate(id: "meditation", nameKey: "Meditation", iconCategory: .mindfulness, type: .duration, suggestedGoalValue: 10, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .morning, category: .mindfulness),
        HabitTemplate(id: "gratitude", nameKey: "Gratitude Practice", iconCategory: .mindfulness, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .morning, category: .mindfulness),
        HabitTemplate(id: "deep-breathing", nameKey: "Deep Breathing", iconCategory: .mindfulness, type: .duration, suggestedGoalValue: 5, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .anytime, category: .mindfulness),
        HabitTemplate(id: "digital-detox", nameKey: "Digital Detox", iconCategory: .mindfulness, type: .duration, suggestedGoalValue: 60, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .evening, category: .mindfulness),

        // Lifestyle
        HabitTemplate(id: "skincare", nameKey: "Skincare Routine", iconCategory: .health, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .evening, category: .lifestyle),
        HabitTemplate(id: "clean-desk", nameKey: "Clean Desk", iconCategory: .chores, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .evening, category: .lifestyle),
        HabitTemplate(id: "budget", nameKey: "Track Expenses", iconCategory: .finance, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .daily, suggestedTimeOfDay: .evening, category: .lifestyle),
        HabitTemplate(id: "social", nameKey: "Connect with Friends", iconCategory: .social, type: .check, suggestedGoalValue: 1, suggestedGoalUnit: nil, suggestedFrequency: .weekly(targetDays: 2), suggestedTimeOfDay: .anytime, category: .lifestyle),
    ]

    static func templates(for category: HabitTemplateCategory) -> [HabitTemplate] {
        allTemplates.filter { $0.category == category }
    }
}
