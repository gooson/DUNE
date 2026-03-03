import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class LifeViewModel {
    private let maxNameLength = 50
    private let maxGoalValue: Double = 1440 // 24 hours in minutes
    private let maxCountGoal: Double = 999
    private let maxIntervalDays = 365
    private let reminderOffsetsInDays = [3, 1, 0]

    private let skipMemoMarker = "[dune-life-cycle-skip]"
    private let snoozeMemoMarker = "[dune-life-cycle-snooze]"

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
    var intervalDays: Int = 7
    var isAutoLinked: Bool = false
    var validationError: String?
    var isSaving = false

    // MARK: - Log Input

    var logInputValue: String = ""

    // MARK: - Progress State

    private(set) var habitProgresses: [HabitProgress] = []
    private(set) var completedCount: Int = 0
    private(set) var totalActiveCount: Int = 0

    struct HabitCycleSnapshot: Sendable {
        let nextDueDate: Date
        let isDue: Bool
        let isOverdue: Bool
        let lastAction: HabitCycleAction?
        let lastCompletedAt: Date?
        let historyCount: Int
    }

    struct HabitHistoryEntry: Identifiable, Sendable {
        let id: UUID
        let action: HabitCycleAction
        let date: Date
        let value: Double
    }

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
        case .interval(let days):
            habit.frequencyTypeRaw = "interval"
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
                validationError = String(localized: "Duration must be between 1 and \(Int(maxGoalValue)) minutes")
                return nil
            }
            clampedValue = value
        case .count:
            guard value > 0, value <= maxCountGoal else {
                validationError = String(localized: "Count must be between 1 and \(Int(maxCountGoal))")
                return nil
            }
            clampedValue = value
        }

        isSaving = true
        return HabitLog(date: date, value: clampedValue)
    }

    func createCycleActionLog(
        for habit: HabitDefinition,
        action: HabitCycleAction,
        date: Date = Date()
    ) -> HabitLog? {
        guard !isSaving else { return nil }
        guard habit.frequency.intervalDays != nil else { return nil }

        let normalizedDate = Calendar.current.startOfDay(for: date)
        let value: Double
        let memo: String?

        switch action {
        case .complete:
            value = 1
            memo = nil
        case .skip:
            value = 0
            memo = skipMemoMarker
        case .snooze:
            value = 0
            memo = snoozeMemoMarker
        }

        isSaving = true
        return HabitLog(date: normalizedDate, value: value, memo: memo)
    }

    // MARK: - Cycle Snapshot / History

    func cycleSnapshot(for habit: HabitDefinition, referenceDate: Date = Date()) -> HabitCycleSnapshot? {
        makeCycleSnapshot(for: habit, referenceDate: referenceDate, calendar: Calendar.current)
    }

    func historyEntries(for habit: HabitDefinition) -> [HabitHistoryEntry] {
        let logs = (habit.logs ?? []).sorted { $0.date > $1.date }
        return logs.map { log in
            HabitHistoryEntry(
                id: log.id,
                action: action(for: log),
                date: log.date,
                value: log.value
            )
        }
    }

    func suggestedSnoozeDate(for habit: HabitDefinition, days: Int = 1, referenceDate: Date = Date()) -> Date? {
        guard let snapshot = cycleSnapshot(for: habit, referenceDate: referenceDate) else { return nil }
        return Calendar.current.date(
            byAdding: .day,
            value: Swift.max(1, days),
            to: snapshot.nextDueDate
        )
    }

    func refreshReminderSchedule(for habit: HabitDefinition, referenceDate: Date = Date()) {
        let snapshot = cycleSnapshot(for: habit, referenceDate: referenceDate)
        Task {
            await HabitReminderScheduler.reschedule(
                habitID: habit.id,
                habitName: habit.name,
                nextDueDate: snapshot?.nextDueDate,
                reminderOffsetsInDays: reminderOffsetsInDays
            )
        }
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
            if let cycleSnapshot = makeCycleSnapshot(for: habit, referenceDate: referenceDate, calendar: calendar) {
                let isCompleted = cycleSnapshot.lastAction == .complete && !cycleSnapshot.isDue
                let effectiveValue = isCompleted ? habit.goalValue : 0

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
                    streak: 0,
                    isAutoLinked: habit.isAutoLinked,
                    isAutoCompleted: false,
                    isCycleBased: true,
                    nextDueDate: cycleSnapshot.nextDueDate,
                    isDue: cycleSnapshot.isDue,
                    isOverdue: cycleSnapshot.isOverdue,
                    lastCycleAction: cycleSnapshot.lastAction,
                    historyCount: cycleSnapshot.historyCount
                ))
                continue
            }

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
                isAutoCompleted: isAutoCompleted,
                isCycleBased: false,
                nextDueDate: nil,
                isDue: false,
                isOverdue: false,
                lastCycleAction: nil,
                historyCount: logs.count
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
            intervalDays = 7
        case .weekly(let days):
            frequencyType = "weekly"
            weeklyTargetDays = days
            intervalDays = 7
        case .interval(let days):
            frequencyType = "interval"
            intervalDays = days
            weeklyTargetDays = 3
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
        intervalDays = 7
        isAutoLinked = false
        validationError = nil
        editingHabit = nil
        logInputValue = ""
    }

    // MARK: - Private

    private func streakDates(habit: HabitDefinition, todayCompleted: Bool, today: Date) -> [Date] {
        var dates = (habit.logs ?? [])
            .filter { action(for: $0) == .complete }
            .map(\.date)

        if todayCompleted, !dates.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
            dates.append(today)
        }
        return dates
    }

    private func makeCycleSnapshot(
        for habit: HabitDefinition,
        referenceDate: Date,
        calendar: Calendar
    ) -> HabitCycleSnapshot? {
        guard let intervalDays = habit.frequency.intervalDays else { return nil }

        let logs = (habit.logs ?? []).sorted { $0.date < $1.date }
        var anchorDate = calendar.startOfDay(for: habit.createdAt)
        var latestSnoozeDate: Date?
        var lastAction: HabitCycleAction?
        var lastCompletedAt: Date?

        for log in logs {
            let action = action(for: log)
            let logDate = calendar.startOfDay(for: log.date)

            switch action {
            case .complete:
                anchorDate = logDate
                lastAction = .complete
                lastCompletedAt = logDate
                latestSnoozeDate = nil
            case .skip:
                anchorDate = logDate
                lastAction = .skip
                latestSnoozeDate = nil
            case .snooze:
                guard logDate >= anchorDate else { continue }
                if let existing = latestSnoozeDate {
                    latestSnoozeDate = logDate > existing ? logDate : existing
                } else {
                    latestSnoozeDate = logDate
                }
            }
        }

        var dueDate = calendar.date(byAdding: .day, value: intervalDays, to: anchorDate) ?? anchorDate
        if let latestSnoozeDate, latestSnoozeDate > dueDate {
            dueDate = latestSnoozeDate
        }

        let today = calendar.startOfDay(for: referenceDate)
        let isDue = today >= dueDate
        let isOverdue = today > dueDate

        return HabitCycleSnapshot(
            nextDueDate: dueDate,
            isDue: isDue,
            isOverdue: isOverdue,
            lastAction: lastAction,
            lastCompletedAt: lastCompletedAt,
            historyCount: logs.count
        )
    }

    private func action(for log: HabitLog) -> HabitCycleAction {
        if log.memo == skipMemoMarker {
            return .skip
        }
        if log.memo == snoozeMemoMarker {
            return .snooze
        }
        return .complete
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
            validationError = String(localized: "Habit name is required")
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
                validationError = String(localized: "Please enter a valid duration")
                return nil
            }
            guard value > 0, value <= maxGoalValue else {
                validationError = String(localized: "Duration must be between 1 and \(Int(maxGoalValue)) minutes")
                return nil
            }
            parsedGoal = value
        case .count:
            let trimmedGoal = goalValue.trimmingCharacters(in: .whitespaces)
            guard !trimmedGoal.isEmpty, let value = Double(trimmedGoal) else {
                validationError = String(localized: "Please enter a valid count")
                return nil
            }
            guard value > 0, value <= maxCountGoal else {
                validationError = String(localized: "Count must be between 1 and \(Int(maxCountGoal))")
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
        } else if frequencyType == "interval" {
            let clampedDays = Swift.max(1, Swift.min(intervalDays, maxIntervalDays))
            frequency = .interval(days: clampedDays)
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

private enum HabitReminderScheduler {
    static func reschedule(
        habitID: UUID,
        habitName: String,
        nextDueDate: Date?,
        reminderOffsetsInDays: [Int]
    ) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = reminderOffsetsInDays.map { notificationID(for: habitID, offsetInDays: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard let nextDueDate else { return }

        let calendar = Calendar.current
        let now = Date()

        for offset in reminderOffsetsInDays {
            guard let candidateDate = calendar.date(byAdding: .day, value: -offset, to: nextDueDate) else {
                continue
            }

            let triggerDate = scheduledTriggerDate(from: candidateDate, calendar: calendar)
            guard triggerDate > now else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: triggerDate)
            components.hour = 9
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = String(localized: "Life Checklist")
            if offset == 0 {
                content.body = String(localized: "\(habitName) is due today")
            } else if offset == 1 {
                content.body = String(localized: "\(habitName) is due in 1 day")
            } else {
                content.body = String(localized: "\(habitName) is due in \(offset) days")
            }
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: notificationID(for: habitID, offsetInDays: offset),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            do {
                try await center.add(request)
            } catch {
                AppLogger.notification.error("[LifeReminder] Failed to schedule habit reminder: \(error.localizedDescription)")
            }
        }
    }

    private static func notificationID(for habitID: UUID, offsetInDays: Int) -> String {
        "dune.life.habit.\(habitID.uuidString).\(offsetInDays)d"
    }

    private static func scheduledTriggerDate(from date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components) ?? date
    }
}
