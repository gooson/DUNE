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
    // Reminder offsets are now computed per-habit via reminderOffsets(for:)

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
    var intervalStartPoint: HabitRecurringStartPoint = .createdAt
    var intervalCustomStartDate: Date = Calendar.current.startOfDay(for: Date())
    var isAutoLinked: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var selectedTimeOfDay: HabitTimeOfDay = .anytime
    var validationError: String?
    var isSaving = false

    // MARK: - Log Input

    var logInputValue: String = ""

    // MARK: - Progress State

    private(set) var habitProgresses: [HabitProgress] = []
    private(set) var completedCount: Int = 0
    private(set) var totalActiveCount: Int = 0
    private(set) var autoExerciseProgresses: [LifeAutoAchievementProgress] =
        LifeAutoAchievementService.calculateProgresses(from: [])

    private(set) var autoLinkedProgresses: [HabitProgress] = []

    /// Context-aware narrative for the Life hero card.
    var heroNarrative: String {
        if totalActiveCount == 0 {
            return String(localized: "Add habits to start tracking your daily routine")
        }
        if completedCount == 0 {
            return String(localized: "\(totalActiveCount) habits waiting — start your day!")
        }
        if completedCount >= totalActiveCount {
            return String(localized: "All done! Great consistency today")
        }
        return String(localized: "\(completedCount) of \(totalActiveCount) habits done — keep going!")
    }

    struct HabitCycleSnapshot: Sendable {
        let nextDueDate: Date?
        let startDate: Date?
        let startPoint: HabitRecurringStartPoint
        let isScheduled: Bool
        let canComplete: Bool
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
            recurringStartPoint: validated.recurringStartPoint,
            recurringCustomStartDate: validated.recurringCustomStartDate,
            recurringStartConfiguredAt: validated.recurringStartConfiguredAt,
            isAutoLinked: validated.isAutoLinked,
            autoLinkSource: validated.isAutoLinked ? "exercise" : nil,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            timeOfDay: selectedTimeOfDay
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
        habit.reminderHour = reminderHour
        habit.reminderMinute = reminderMinute
        habit.timeOfDayRaw = selectedTimeOfDay.rawValue

        let calendar = Calendar.current
        let previousStartPoint = habit.recurringStartPoint
        let previousCustomDate = habit.recurringCustomStartDate.map { calendar.startOfDay(for: $0) }
        let nextCustomDate = validated.recurringCustomStartDate.map { calendar.startOfDay(for: $0) }
        let wasInterval = habit.frequency.intervalDays != nil
        let recurringStartPointChanged = previousStartPoint != validated.recurringStartPoint
            || previousCustomDate != nextCustomDate

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
            habit.recurringStartPointRaw = validated.recurringStartPoint.rawValue
            habit.recurringCustomStartDate = nextCustomDate
            if !wasInterval || recurringStartPointChanged {
                habit.recurringStartConfiguredAt = validated.recurringStartConfiguredAt
            }
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
        guard let nextDueDate = snapshot.nextDueDate else { return nil }
        return Calendar.current.date(
            byAdding: .day,
            value: Swift.max(1, days),
            to: nextDueDate
        )
    }

    func refreshReminderSchedule(for habit: HabitDefinition, referenceDate: Date = Date()) {
        let snapshot = cycleSnapshot(for: habit, referenceDate: referenceDate)
        let offsets = HabitReminderScheduler.reminderOffsets(for: habit.frequency)
        Task {
            await HabitReminderScheduler.reschedule(
                habitID: habit.id,
                habitName: habit.name,
                nextDueDate: snapshot?.nextDueDate,
                reminderOffsetsInDays: offsets,
                reminderHour: habit.reminderHour,
                reminderMinute: habit.reminderMinute
            )
        }
    }

    /// Cancel all pending reminders for this habit (called after early completion).
    func cancelPendingReminders(for habit: HabitDefinition) {
        Task {
            await HabitReminderScheduler.removeAllReminders(habitID: habit.id)
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

        for habit in habits where !habit.isArchived {
            if let cycleSnapshot = makeCycleSnapshot(for: habit, referenceDate: referenceDate, calendar: calendar) {
                let isCompleted = cycleSnapshot.lastAction == .complete && !cycleSnapshot.isDue
                let effectiveValue = isCompleted ? habit.goalValue : 0



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
                    canCompleteCycle: cycleSnapshot.canComplete,
                    nextDueDate: cycleSnapshot.nextDueDate,
                    cycleStartDate: cycleSnapshot.startDate,
                    cycleStartPoint: cycleSnapshot.startPoint,
                    isScheduled: cycleSnapshot.isScheduled,
                    isDue: cycleSnapshot.isDue,
                    isOverdue: cycleSnapshot.isOverdue,
                    lastCycleAction: cycleSnapshot.lastAction,
                    historyCount: cycleSnapshot.historyCount,
                    timeOfDay: habit.timeOfDay
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
                canCompleteCycle: false,
                nextDueDate: nil,
                cycleStartDate: nil,
                cycleStartPoint: nil,
                isScheduled: false,
                isDue: false,
                isOverdue: false,
                lastCycleAction: nil,
                historyCount: logs.count,
                timeOfDay: habit.timeOfDay
            ))
        }

        habitProgresses = progresses
        autoLinkedProgresses = progresses.filter(\.isAutoLinked)

        let manualProgresses = progresses.filter { !$0.isAutoLinked }
        completedCount = manualProgresses.filter(\.isCompleted).count
        totalActiveCount = manualProgresses.count
    }

    func calculateAutoExerciseProgresses(
        exerciseRecords: [ExerciseRecord],
        referenceDate: Date = Date()
    ) {
        let entries: [LifeAutoWorkoutEntry] = exerciseRecords.map { record in
            let linkedWorkoutID = record.healthKitWorkoutID?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return LifeAutoWorkoutEntry(
                sourceWorkoutID: linkedWorkoutID?.isEmpty == true ? nil : linkedWorkoutID,
                date: record.date,
                activityID: record.exerciseDefinitionID,
                exerciseType: record.exerciseType,
                distance: record.distance,
                hasSetData: record.hasSetData,
                primaryMuscles: record.primaryMuscles,
                secondaryMuscles: record.secondaryMuscles,
                isFromHealthKit: record.isFromHealthKit,
                hasHealthKitLink: linkedWorkoutID?.isEmpty == false
            )
        }

        autoExerciseProgresses = LifeAutoAchievementService.calculateProgresses(
            from: entries,
            referenceDate: referenceDate
        )
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
        reminderHour = habit.reminderHour
        reminderMinute = habit.reminderMinute
        selectedTimeOfDay = habit.timeOfDay
        validationError = nil

        switch habit.frequency {
        case .daily:
            frequencyType = "daily"
            weeklyTargetDays = 7
            intervalDays = 7
            intervalStartPoint = .createdAt
            intervalCustomStartDate = calendarStartOfDay(Date())
        case .weekly(let days):
            frequencyType = "weekly"
            weeklyTargetDays = days
            intervalDays = 7
            intervalStartPoint = .createdAt
            intervalCustomStartDate = calendarStartOfDay(Date())
        case .interval(let days):
            frequencyType = "interval"
            intervalDays = days
            weeklyTargetDays = 3
            intervalStartPoint = habit.recurringStartPoint
            intervalCustomStartDate = calendarStartOfDay(habit.recurringCustomStartDate ?? Date())
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
        intervalStartPoint = .createdAt
        intervalCustomStartDate = calendarStartOfDay(Date())
        isAutoLinked = false
        reminderHour = 9
        reminderMinute = 0
        selectedTimeOfDay = .anytime
        validationError = nil
        editingHabit = nil
        logInputValue = ""
    }

    // MARK: - Template Prefill

    func prefillFromTemplate(_ template: HabitTemplate) {
        name = template.name
        selectedIconCategory = template.iconCategory
        selectedType = template.type
        goalValue = template.type == .check ? "1" : String(format: "%.0f", template.suggestedGoalValue)
        goalUnit = template.suggestedGoalUnit ?? ""
        selectedTimeOfDay = template.suggestedTimeOfDay

        switch template.suggestedFrequency {
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
            intervalStartPoint = .createdAt
        }

        validationError = nil
    }

    // MARK: - Private

    private func calendarStartOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

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

        let allLogs = (habit.logs ?? []).sorted { $0.date < $1.date }
        let configuredAt = calendarStartOfDay(habit.recurringStartConfiguredAt ?? habit.createdAt)
        let logs = allLogs.filter { calendarStartOfDay($0.date) >= configuredAt }
        let startPoint = habit.recurringStartPoint
        let today = calendarStartOfDay(referenceDate)

        let startDate: Date?
        switch startPoint {
        case .createdAt:
            startDate = calendarStartOfDay(habit.createdAt)
        case .today:
            startDate = configuredAt
        case .customDate:
            startDate = calendarStartOfDay(habit.recurringCustomStartDate ?? configuredAt)
        case .firstCompletion:
            startDate = logs.first(where: { action(for: $0) == .complete })
                .map { calendarStartOfDay($0.date) }
        }

        guard let startDate else {
            return HabitCycleSnapshot(
                nextDueDate: nil,
                startDate: nil,
                startPoint: startPoint,
                isScheduled: true,
                canComplete: startPoint == .firstCompletion,
                isDue: false,
                isOverdue: false,
                lastAction: nil,
                lastCompletedAt: nil,
                historyCount: logs.count
            )
        }

        if today < startDate {
            let firstDueDate = calendar.date(byAdding: .day, value: intervalDays, to: startDate)
            return HabitCycleSnapshot(
                nextDueDate: firstDueDate,
                startDate: startDate,
                startPoint: startPoint,
                isScheduled: true,
                canComplete: false,
                isDue: false,
                isOverdue: false,
                lastAction: nil,
                lastCompletedAt: nil,
                historyCount: logs.count
            )
        }

        var anchorDate = startDate
        var latestSnoozeDate: Date?
        var lastAction: HabitCycleAction?
        var lastCompletedAt: Date?

        for log in logs {
            let action = action(for: log)
            let logDate = calendarStartOfDay(log.date)
            guard logDate >= startDate else { continue }

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

        let isDue = today >= dueDate
        let isOverdue = today > dueDate
        // Early completion: always completable unless already completed in current cycle
        let isCompletedThisCycle = lastAction == .complete && !isDue
        let canComplete = !isCompletedThisCycle

        return HabitCycleSnapshot(
            nextDueDate: dueDate,
            startDate: startDate,
            startPoint: startPoint,
            isScheduled: false,
            canComplete: canComplete,
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
        let recurringStartPoint: HabitRecurringStartPoint
        let recurringCustomStartDate: Date?
        let recurringStartConfiguredAt: Date?
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
        let recurringStartPoint: HabitRecurringStartPoint
        let recurringCustomStartDate: Date?
        let recurringStartConfiguredAt: Date?
        if frequencyType == "weekly" {
            let clampedDays = Swift.max(1, Swift.min(weeklyTargetDays, 7))
            frequency = .weekly(targetDays: clampedDays)
            recurringStartPoint = .createdAt
            recurringCustomStartDate = nil
            recurringStartConfiguredAt = nil
        } else if frequencyType == "interval" {
            let clampedDays = Swift.max(1, Swift.min(intervalDays, maxIntervalDays))
            frequency = .interval(days: clampedDays)
            recurringStartPoint = intervalStartPoint
            recurringCustomStartDate = intervalStartPoint == .customDate
                ? calendarStartOfDay(intervalCustomStartDate)
                : nil
            recurringStartConfiguredAt = calendarStartOfDay(Date())
        } else {
            frequency = .daily
            recurringStartPoint = .createdAt
            recurringCustomStartDate = nil
            recurringStartConfiguredAt = nil
        }

        return ValidatedHabitInput(
            name: safeName,
            iconCategory: selectedIconCategory,
            habitType: selectedType,
            goalValue: parsedGoal,
            goalUnit: safeUnit,
            frequency: frequency,
            recurringStartPoint: recurringStartPoint,
            recurringCustomStartDate: recurringCustomStartDate,
            recurringStartConfiguredAt: recurringStartConfiguredAt,
            isAutoLinked: isAutoLinked
        )
    }
}

enum HabitReminderScheduler {

    // MARK: - Interval-Proportional Offsets

    static func reminderOffsets(for frequency: HabitFrequency) -> [Int] {
        switch frequency {
        case .daily:
            return [0]
        case .weekly:
            return [0]
        case .interval(let days):
            switch days {
            case 1:       return [0]
            case 2...7:   return [1, 0]
            case 8...14:  return [3, 1, 0]
            case 15...30: return [7, 3, 1, 0]
            default:      return [14, 7, 3, 0]
            }
        }
    }

    // MARK: - Schedule

    static func reschedule(
        habitID: UUID,
        habitName: String,
        nextDueDate: Date?,
        reminderOffsetsInDays: [Int],
        reminderHour: Int = 9,
        reminderMinute: Int = 0
    ) async {
        let center = UNUserNotificationCenter.current()

        // Remove all existing reminders for this habit (use broad prefix match)
        await removeAllReminders(habitID: habitID)

        guard let nextDueDate else { return }

        let calendar = Calendar.current
        let now = Date()
        let hour = max(0, min(reminderHour, 23))
        let minute = max(0, min(reminderMinute, 59))

        for offset in reminderOffsetsInDays {
            guard let candidateDate = calendar.date(byAdding: .day, value: -offset, to: nextDueDate) else {
                continue
            }

            var components = calendar.dateComponents([.year, .month, .day], from: candidateDate)
            components.hour = hour
            components.minute = minute

            guard let triggerDate = calendar.date(from: components), triggerDate > now else { continue }

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
            content.userInfo = NotificationResponsePayload(
                routeKind: NotificationRoute.notificationHub.destination.rawValue,
                insightType: HealthInsight.InsightType.lifeChecklistReminder.rawValue
            ).userInfo

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

    // MARK: - Cancel All Reminders

    static func removeAllReminders(habitID: UUID) async {
        let center = UNUserNotificationCenter.current()
        let prefix = "dune.life.habit.\(habitID.uuidString)."
        let pending = await center.pendingNotificationRequests()
        let matching = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        if !matching.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: matching)
        }
    }

    private static func notificationID(for habitID: UUID, offsetInDays: Int) -> String {
        "dune.life.habit.\(habitID.uuidString).\(offsetInDays)d"
    }
}
