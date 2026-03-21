import Foundation
import SwiftData

@Model
final class HabitDefinition {
    var id: UUID = UUID()
    var name: String = ""
    var iconCategoryRaw: String = "health"
    // WARNING: rawValue is persisted in CloudKit. Do NOT rename enum cases. (Correction #164)
    var habitTypeRaw: String = "check"
    var goalValue: Double = 1.0
    var goalUnit: String?
    // WARNING: rawValue is persisted in CloudKit. Do NOT rename. (Correction #164)
    var frequencyTypeRaw: String = "daily"
    var weeklyTargetDays: Int = 3
    // WARNING: rawValue is persisted in CloudKit. Do NOT rename. (Correction #164)
    var recurringStartPointRaw: String = "createdAt"
    var recurringCustomStartDate: Date?
    var recurringStartConfiguredAt: Date?
    var isAutoLinked: Bool = false
    var autoLinkSourceRaw: String?
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var timeOfDayRaw: String = "anytime"

    // CloudKit: relationship MUST be Optional (Correction #32)
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habitDefinition)
    var logs: [HabitLog]? = []

    // MARK: - Computed Properties

    var habitType: HabitType {
        HabitType(rawValue: habitTypeRaw) ?? .check
    }

    var iconCategory: HabitIconCategory {
        HabitIconCategory(rawValue: iconCategoryRaw) ?? .health
    }

    var frequency: HabitFrequency {
        if frequencyTypeRaw == "weekly" {
            return .weekly(targetDays: Swift.max(1, Swift.min(weeklyTargetDays, 7)))
        }
        if frequencyTypeRaw == "interval" {
            return .interval(days: Swift.max(1, Swift.min(weeklyTargetDays, 365)))
        }
        return .daily
    }

    var recurringStartPoint: HabitRecurringStartPoint {
        HabitRecurringStartPoint(rawValue: recurringStartPointRaw) ?? .createdAt
    }

    var timeOfDay: HabitTimeOfDay {
        HabitTimeOfDay(rawValue: timeOfDayRaw) ?? .anytime
    }

    // MARK: - Init

    init(
        name: String,
        iconCategory: HabitIconCategory,
        habitType: HabitType,
        goalValue: Double,
        goalUnit: String?,
        frequency: HabitFrequency,
        recurringStartPoint: HabitRecurringStartPoint = .createdAt,
        recurringCustomStartDate: Date? = nil,
        recurringStartConfiguredAt: Date? = nil,
        isAutoLinked: Bool = false,
        autoLinkSource: String? = nil,
        sortOrder: Int = 0,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        timeOfDay: HabitTimeOfDay = .anytime
    ) {
        self.id = UUID()
        self.name = name
        self.iconCategoryRaw = iconCategory.rawValue
        self.habitTypeRaw = habitType.rawValue
        self.goalValue = goalValue
        self.goalUnit = goalUnit
        self.isAutoLinked = isAutoLinked
        self.autoLinkSourceRaw = autoLinkSource
        self.sortOrder = sortOrder
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.timeOfDayRaw = timeOfDay.rawValue
        self.createdAt = Date()

        let calendar = Calendar.current
        let normalizedConfiguredAt = calendar.startOfDay(for: recurringStartConfiguredAt ?? Date())
        let normalizedCustomStartDate = recurringCustomStartDate.map { calendar.startOfDay(for: $0) }

        switch frequency {
        case .daily:
            self.frequencyTypeRaw = "daily"
            self.weeklyTargetDays = 7
            self.recurringStartPointRaw = HabitRecurringStartPoint.createdAt.rawValue
            self.recurringCustomStartDate = nil
            self.recurringStartConfiguredAt = nil
        case .weekly(let days):
            self.frequencyTypeRaw = "weekly"
            self.weeklyTargetDays = days
            self.recurringStartPointRaw = HabitRecurringStartPoint.createdAt.rawValue
            self.recurringCustomStartDate = nil
            self.recurringStartConfiguredAt = nil
        case .interval(let days):
            self.frequencyTypeRaw = "interval"
            self.weeklyTargetDays = days
            self.recurringStartPointRaw = recurringStartPoint.rawValue
            self.recurringCustomStartDate = recurringStartPoint == .customDate ? normalizedCustomStartDate : nil
            self.recurringStartConfiguredAt = normalizedConfiguredAt
        }
    }
}
