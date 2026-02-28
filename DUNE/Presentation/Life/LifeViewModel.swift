import Foundation
import Observation

@Observable
@MainActor
final class LifeViewModel {
    private let maxNameLength = 50
    private let maxMemoLength = 200
    private let maxGoalValue: Double = 1440 // 24 hours in minutes
    private let maxCountGoal: Double = 999

    // MARK: - Sheet State

    var isShowingAddSheet = false
    var isShowingEditSheet = false
    var editingHabit: HabitDefinition?

    // MARK: - Form Fields

    var name: String = "" { didSet { validationError = nil } }
    var selectedIconCategory: HabitIconCategory = .health
    var selectedType: HabitType = .check
    var goalValue: String = "1"
    var goalUnit: String = ""
    var frequencyType: String = "daily"
    var weeklyTargetDays: Int = 3
    var isAutoLinked: Bool = false
    var validationError: String?
    var isSaving = false

    // MARK: - Log Input

    var logInputValue: String = ""

    // MARK: - Progress State

    private(set) var habitProgresses: [HabitProgress] = []
    private(set) var completedCount: Int = 0
    private(set) var totalActiveCount: Int = 0

    // MARK: - Habit CRUD

    func createValidatedHabit() -> HabitDefinition? {
        guard !isSaving else { return nil }
        guard let validated = validateHabitInputs() else { return nil }
        isSaving = true

        return HabitDefinition(
            name: validated.name,
            iconCategory: validated.iconCategory,
            habitType: validated.habitType,
            goalValue: validated.goalValue,
            goalUnit: validated.goalUnit,
            frequency: validated.frequency,
            isAutoLinked: validated.isAutoLinked,
            autoLinkSource: validated.isAutoLinked ? "exercise" : nil
        )
    }

    func applyUpdate(to habit: HabitDefinition) -> Bool {
        guard !isSaving else { return false }
        guard let validated = validateHabitInputs() else { return false }
        isSaving = true

        habit.name = validated.name
        habit.iconCategoryRaw = validated.iconCategory.rawValue
        habit.habitTypeRaw = validated.habitType.rawValue
        habit.goalValue = validated.goalValue
        habit.goalUnit = validated.goalUnit
        habit.isAutoLinked = validated.isAutoLinked
        habit.autoLinkSourceRaw = validated.isAutoLinked ? "exercise" : nil

        switch validated.frequency {
        case .daily:
            habit.frequencyTypeRaw = "daily"
            habit.weeklyTargetDays = 7
        case .weekly(let days):
            habit.frequencyTypeRaw = "weekly"
            habit.weeklyTargetDays = days
        }

        // Caller (View) must call didFinishSaving() after SwiftData auto-save (Correction #43)
        return true
    }

    /// Call from View after `modelContext.insert(record)` completes.
    func didFinishSaving() {
        isSaving = false
    }

    // MARK: - Log CRUD

    func createValidatedLog(for habit: HabitDefinition, value: Double, date: Date = Date()) -> HabitLog? {
        guard !isSaving else { return nil }

        let clampedValue: Double
        switch habit.habitType {
        case .check:
            clampedValue = 1.0
        case .duration:
            guard value > 0, value <= maxGoalValue else {
                validationError = "Duration must be between 1 and \(Int(maxGoalValue)) minutes"
                return nil
            }
            clampedValue = value
        case .count:
            guard value > 0, value <= maxCountGoal else {
                validationError = "Count must be between 1 and \(Int(maxCountGoal))"
                return nil
            }
            clampedValue = value
        }

        isSaving = true
        return HabitLog(date: date, value: clampedValue)
    }

    // MARK: - Progress Calculation

    func calculateProgresses(
        habits: [HabitDefinition],
        todayExerciseExists: Bool,
        referenceDate: Date = Date()
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        var progresses: [HabitProgress] = []
        var completed = 0

        for habit in habits where !habit.isArchived {
            let logs = (habit.logs ?? [])
            let todayLogs = logs.filter { calendar.isDate($0.date, inSameDayAs: today) }
            let todayValue = todayLogs.reduce(0.0) { $0 + $1.value }

            // Auto-link: exercise
            let effectiveValue: Double
            let isAutoCompleted: Bool
            if habit.isAutoLinked, habit.autoLinkSourceRaw == "exercise" {
                isAutoCompleted = todayExerciseExists
                effectiveValue = isAutoCompleted ? Swift.max(todayValue, habit.goalValue) : todayValue
            } else {
                isAutoCompleted = false
                effectiveValue = todayValue
            }

            let isCompleted = effectiveValue >= habit.goalValue

            let streak = HabitStreakService.calculateStreak(
                completedDates: streakDates(habit: habit, todayCompleted: isCompleted, today: today),
                frequency: habit.frequency,
                referenceDate: referenceDate
            )

            if isCompleted { completed += 1 }

            progresses.append(HabitProgress(
                id: habit.id,
                name: habit.name,
                iconCategory: habit.iconCategory,
                type: habit.habitType,
                goalValue: habit.goalValue,
                goalUnit: habit.goalUnit,
                frequency: habit.frequency,
                todayValue: effectiveValue,
                isCompleted: isCompleted,
                streak: streak,
                isAutoLinked: habit.isAutoLinked,
                isAutoCompleted: isAutoCompleted
            ))
        }

        habitProgresses = progresses
        completedCount = completed
        totalActiveCount = progresses.count
    }

    // MARK: - Form Helpers

    func startEditing(_ habit: HabitDefinition) {
        editingHabit = habit
        name = habit.name
        selectedIconCategory = habit.iconCategory
        selectedType = habit.habitType
        goalValue = habit.habitType == .check ? "1" : String(format: "%.0f", habit.goalValue)
        goalUnit = habit.goalUnit ?? ""
        isAutoLinked = habit.isAutoLinked
        validationError = nil

        switch habit.frequency {
        case .daily:
            frequencyType = "daily"
            weeklyTargetDays = 7
        case .weekly(let days):
            frequencyType = "weekly"
            weeklyTargetDays = days
        }

        isShowingEditSheet = true
    }

    func resetForm() {
        name = ""
        selectedIconCategory = .health
        selectedType = .check
        goalValue = "1"
        goalUnit = ""
        frequencyType = "daily"
        weeklyTargetDays = 3
        isAutoLinked = false
        validationError = nil
        editingHabit = nil
        logInputValue = ""
    }

    // MARK: - Private

    private func streakDates(habit: HabitDefinition, todayCompleted: Bool, today: Date) -> [Date] {
        var dates = (habit.logs ?? []).map(\.date)
        if todayCompleted, !dates.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
            dates.append(today)
        }
        return dates
    }

    private struct ValidatedHabitInput {
        let name: String
        let iconCategory: HabitIconCategory
        let habitType: HabitType
        let goalValue: Double
        let goalUnit: String?
        let frequency: HabitFrequency
        let isAutoLinked: Bool
    }

    private func validateHabitInputs() -> ValidatedHabitInput? {
        validationError = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            validationError = "Habit name is required"
            return nil
        }

        let safeName = String(trimmedName.prefix(maxNameLength))

        let parsedGoal: Double
        switch selectedType {
        case .check:
            parsedGoal = 1.0
        case .duration:
            let trimmedGoal = goalValue.trimmingCharacters(in: .whitespaces)
            guard !trimmedGoal.isEmpty, let value = Double(trimmedGoal) else {
                validationError = "Please enter a valid duration"
                return nil
            }
            guard value > 0, value <= maxGoalValue else {
                validationError = "Duration must be between 1 and \(Int(maxGoalValue)) minutes"
                return nil
            }
            parsedGoal = value
        case .count:
            let trimmedGoal = goalValue.trimmingCharacters(in: .whitespaces)
            guard !trimmedGoal.isEmpty, let value = Double(trimmedGoal) else {
                validationError = "Please enter a valid count"
                return nil
            }
            guard value > 0, value <= maxCountGoal else {
                validationError = "Count must be between 1 and \(Int(maxCountGoal))"
                return nil
            }
            parsedGoal = value
        }

        let trimmedUnit = goalUnit.trimmingCharacters(in: .whitespaces)
        let safeUnit: String? = trimmedUnit.isEmpty ? nil : String(trimmedUnit.prefix(20))

        let frequency: HabitFrequency
        if frequencyType == "weekly" {
            let clampedDays = Swift.max(1, Swift.min(weeklyTargetDays, 7))
            frequency = .weekly(targetDays: clampedDays)
        } else {
            frequency = .daily
        }

        return ValidatedHabitInput(
            name: safeName,
            iconCategory: selectedIconCategory,
            habitType: selectedType,
            goalValue: parsedGoal,
            goalUnit: safeUnit,
            frequency: frequency,
            isAutoLinked: isAutoLinked
        )
    }
}
