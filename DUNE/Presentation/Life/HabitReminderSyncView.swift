import SwiftUI
import SwiftData

extension Notification.Name {
    static let habitReminderAuthorizationGranted = Notification.Name("dune.habitReminderAuthorizationGranted")
}

/// Keeps persisted habits scheduled even when the Life tab has not been opened.
struct HabitReminderSyncView: View {
    @Query private var habits: [HabitDefinition]
    @Query private var logs: [HabitLog]
    @Query private var recentExerciseRecords: [ExerciseRecord]
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = LifeViewModel()
    @State private var syncState = HabitReminderSyncState()
    @State private var refreshGeneration = 0

    init() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let recentStart = calendar.date(byAdding: .day, value: -2, to: today) ?? .distantPast
        // Keep every interval anchor, but avoid loading past daily/weekly history.
        // Two extra days cover date-boundary changes when the system time zone changes.
        _logs = Query(filter: #Predicate<HabitLog> {
            $0.date >= recentStart || $0.habitDefinition?.frequencyTypeRaw == "interval"
        })
        _recentExerciseRecords = Query(filter: #Predicate<ExerciseRecord> {
            $0.date >= recentStart
        })
    }

    private var currentSnapshot: HabitReminderSyncState.Snapshot {
        var habitSignatures: [UUID: Int] = [:]
        var autoLinkedHabitIDs = Set<UUID>()
        for habit in habits {
            var hasher = Hasher()
            hasher.combine(habit.name)
            hasher.combine(habit.isArchived)
            hasher.combine(habit.frequencyTypeRaw)
            hasher.combine(habit.weeklyTargetDays)
            hasher.combine(habit.goalValue)
            hasher.combine(habit.createdAt)
            hasher.combine(habit.recurringStartPointRaw)
            hasher.combine(habit.recurringCustomStartDate)
            hasher.combine(habit.recurringStartConfiguredAt)
            hasher.combine(habit.reminderHour)
            hasher.combine(habit.reminderMinute)
            hasher.combine(habit.isAutoLinked)
            hasher.combine(habit.autoLinkSourceRaw)
            habitSignatures[habit.id] = hasher.finalize()
            if habit.isAutoLinked, habit.autoLinkSourceRaw == "exercise" {
                autoLinkedHabitIDs.insert(habit.id)
            }
        }
        var logSignatures: [UUID: HabitReminderSyncState.Log] = [:]
        for log in logs {
            var hasher = Hasher()
            hasher.combine(log.date)
            hasher.combine(log.value)
            hasher.combine(log.isAutoCompleted)
            hasher.combine(log.memo)
            hasher.combine(log.completedAt)
            logSignatures[log.id] = .init(habitID: log.habitDefinition?.id,
                                          signature: hasher.finalize())
        }
        return .init(
            habits: habitSignatures,
            logs: logSignatures,
            autoLinkedHabitIDs: autoLinkedHabitIDs,
            todayExerciseExists: HabitReminderSyncState.exerciseExists(
                on: recentExerciseRecords.map(\.date), referenceDate: Date()),
            generation: refreshGeneration
        )
    }

    var body: some View {
        let snapshot = currentSnapshot
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: snapshot) {
                // Cloud imports can deliver many related changes in successive updates.
                do {
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                synchronize(snapshot: snapshot)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshGeneration += 1 }
            }
            .onReceive(NotificationCenter.default.mainThreadPublisher(for: .habitReminderAuthorizationGranted)) { _ in
                refreshGeneration += 1
            }
            .onReceive(NotificationCenter.default.mainThreadPublisher(for: .NSCalendarDayChanged)) { _ in
                refreshGeneration += 1
            }
            .onReceive(NotificationCenter.default.mainThreadPublisher(for: .NSSystemTimeZoneDidChange)) { _ in
                refreshGeneration += 1
            }
    }

    private func synchronize(snapshot: HabitReminderSyncState.Snapshot) {
        let plan = syncState.plan(for: snapshot)
        if plan.cleanUpOrphans {
            viewModel.cleanupOrphanedReminders(validHabitIDs: Set(snapshot.habits.keys))
        }
        guard !plan.habitIDs.isEmpty else { return }
        let logsByHabit = Dictionary(grouping: logs, by: { $0.habitDefinition?.id })
        for habit in habits where plan.habitIDs.contains(habit.id) {
            viewModel.refreshReminderSchedule(
                for: habit,
                additionalLogs: logsByHabit[habit.id] ?? [],
                todayExerciseExists: snapshot.todayExerciseExists
            )
        }
    }
}
