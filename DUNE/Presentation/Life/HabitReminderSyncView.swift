import SwiftUI
import SwiftData

extension Notification.Name {
    static let habitReminderAuthorizationGranted = Notification.Name("dune.habitReminderAuthorizationGranted")
}

/// Keeps persisted habits scheduled even when the Life tab has not been opened.
struct HabitReminderSyncView: View {
    @Query private var habits: [HabitDefinition]
    @Query private var logs: [HabitLog]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = LifeViewModel()
    @State private var syncState = HabitReminderSyncState()
    @State private var refreshGeneration = 0
    @State private var tombstoneGeneration = 0
    @State private var localWorkoutSource: HabitReminderSyncState.WorkoutSource = .pending
    private let healthWorkouts = LifeHealthKitWorkouts.shared

    let canLoadHealthKitData: Bool

    init(canLoadHealthKitData: Bool) {
        self.canLoadHealthKitData = canLoadHealthKitData
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let recentStart = calendar.date(byAdding: .day, value: -2, to: today) ?? .distantPast
        // Keep every interval anchor, but avoid loading past daily/weekly history.
        // Two extra days cover date-boundary changes when the system time zone changes.
        _logs = Query(filter: #Predicate<HabitLog> {
            $0.date >= recentStart || $0.habitDefinition?.frequencyTypeRaw == "interval"
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
            if !habit.isArchived, habit.isAutoLinked, habit.autoLinkSourceRaw == "exercise" {
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
            workoutSource: workoutSource,
            generation: refreshGeneration
        )
    }

    private var workoutSource: HabitReminderSyncState.WorkoutSource {
        guard case .resolved(let localDate) = localWorkoutSource else { return .pending }
        guard healthWorkouts.isReminderHealthDataAvailable else { return .resolved(localDate) }
        guard canLoadHealthKitData else { return .pending }
        return LifeHealthKitWorkouts.combinedReminderDate(local: localDate, health: healthWorkouts.reminderHealthWorkoutSource)
    }

    var body: some View {
        let snapshot = currentSnapshot
        let needsWorkoutDate = !snapshot.autoLinkedHabitIDs.isEmpty
        let refreshHealthWorkoutDate = scenePhase == .active && needsWorkoutDate
            && canLoadHealthKitData && healthWorkouts.isReminderHealthDataAvailable
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: needsWorkoutDate ? refreshGeneration : nil) {
                if needsWorkoutDate { refreshLocalWorkoutDate() }
            }
            .task(id: refreshHealthWorkoutDate ? [refreshGeneration, tombstoneGeneration, healthWorkouts.reminderAccessGeneration] : nil) {
                if refreshHealthWorkoutDate, !Task.isCancelled {
                    await healthWorkouts.refreshReminderHealthWorkoutDate(before: Date())
                }
            }
            .task(id: snapshot) {
                // Cloud imports can deliver many related changes in successive updates.
                do {
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    return
                }
                guard !Task.isCancelled, snapshot == currentSnapshot else { return }
                synchronize(snapshot: snapshot)
            }
            .onReceive(NotificationCenter.default.mainThreadPublisher(for: ModelContext.didSave)) { notification in
                if needsWorkoutDate, Self.containsWorkoutChanges(notification) {
                    refreshLocalWorkoutDate()
                    if refreshHealthWorkoutDate, !healthWorkouts.reminderLookupIncludesCurrentTombstones {
                        tombstoneGeneration += 1
                    }
                }
            }
            .onReceive(NotificationCenter.default.mainThreadPublisher(for: .NSPersistentStoreRemoteChange)) { _ in
                if needsWorkoutDate { refreshLocalWorkoutDate() }
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

    private static func containsWorkoutChanges(_ notification: Notification) -> Bool {
        let entity = Schema.entityName(for: ExerciseRecord.self)
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        return keys.contains { key in
            let identifiers = notification.userInfo?[key.rawValue] as? Set<PersistentIdentifier>
            return identifiers?.contains { $0.entityName == entity } == true
        }
    }

    private func refreshLocalWorkoutDate() {
        do {
            let latest = try LifeHealthKitWorkouts.latestLocalWorkoutDate(in: modelContext, before: Date())
            localWorkoutSource = .resolved(latest)
        } catch {
            localWorkoutSource = .pending
            AppLogger.notification.error("Local workout date query failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func synchronize(snapshot: HabitReminderSyncState.Snapshot) {
        let plan = syncState.plan(for: snapshot)
        if plan.cleanUpOrphans {
            viewModel.cleanupOrphanedReminders(validHabitIDs: Set(snapshot.habits.keys))
        }
        guard !plan.habitIDs.isEmpty else { return }
        let logsByHabit = Dictionary(grouping: logs, by: { $0.habitDefinition?.id })
        let now = Date()
        let latestDate: Date?
        if case .resolved(let date) = snapshot.workoutSource {
            latestDate = date
        } else {
            latestDate = nil
        }
        let todayExerciseExists = latestDate.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
        viewModel.setWorkoutDates(latestDate.map { [$0] } ?? [])
        for habit in habits where plan.habitIDs.contains(habit.id) {
            viewModel.refreshReminderSchedule(
                for: habit,
                referenceDate: now,
                additionalLogs: logsByHabit[habit.id] ?? [],
                todayExerciseExists: todayExerciseExists
            )
        }
    }
}
