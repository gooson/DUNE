import SwiftUI
import SwiftData

extension Notification.Name {
    static let habitReminderAuthorizationGranted = Notification.Name("dune.habitReminderAuthorizationGranted")
}

/// Keeps persisted habits scheduled even when the Life tab has not been opened.
struct HabitReminderSyncView: View {
    @Query private var habits: [HabitDefinition]
    @Query(filter: #Predicate<HabitLog> { $0.habitDefinition?.frequencyTypeRaw == "interval" })
    private var logs: [HabitLog]
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = LifeViewModel()

    private var scheduleSignature: Int {
        var hasher = Hasher()
        for habit in habits {
            hasher.combine(habit.id)
            hasher.combine(habit.name)
            hasher.combine(habit.isArchived)
            hasher.combine(habit.frequencyTypeRaw)
            hasher.combine(habit.weeklyTargetDays)
            hasher.combine(habit.createdAt)
            hasher.combine(habit.recurringStartPointRaw)
            hasher.combine(habit.recurringCustomStartDate)
            hasher.combine(habit.recurringStartConfiguredAt)
            hasher.combine(habit.reminderHour)
            hasher.combine(habit.reminderMinute)
        }
        // Interval anchors may be arbitrarily old; filtering by a date window would lose them.
        for log in logs {
            hasher.combine(log.id)
            hasher.combine(log.habitDefinition?.id)
            hasher.combine(log.date)
            hasher.combine(log.value)
            hasher.combine(log.memo)
        }
        return hasher.finalize()
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: scheduleSignature, initial: true) { _, _ in synchronize() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { synchronize() }
            }
            .onReceive(NotificationCenter.default.mainThreadPublisher(for: .habitReminderAuthorizationGranted)) { _ in
                synchronize()
            }
    }

    private func synchronize() {
        let currentIDs = Set(habits.map(\.id))
        viewModel.cleanupOrphanedReminders(validHabitIDs: currentIDs)
        for habit in habits {
            viewModel.refreshReminderSchedule(for: habit)
        }
    }
}
