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
    var isAutoLinked: Bool = false
    var autoLinkSourceRaw: String?
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()

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
        return .daily
    }

    // MARK: - Init

    init(
        name: String,
        iconCategory: HabitIconCategory,
        habitType: HabitType,
        goalValue: Double,
        goalUnit: String?,
        frequency: HabitFrequency,
        isAutoLinked: Bool = false,
        autoLinkSource: String? = nil,
        sortOrder: Int = 0
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
        self.createdAt = Date()

        switch frequency {
        case .daily:
            self.frequencyTypeRaw = "daily"
            self.weeklyTargetDays = 7
        case .weekly(let days):
            self.frequencyTypeRaw = "weekly"
            self.weeklyTargetDays = days
        }
    }
}
