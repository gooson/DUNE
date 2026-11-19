import Foundation
import Testing
@testable import DUNE

@Suite("HabitReminderSyncState")
struct HabitReminderSyncStateTests {
    private let first = UUID(uuidString: "30C4A651-993F-403B-9D1D-19D37196E258")!
    private let second = UUID(uuidString: "1292BA98-5C06-44D1-A3F4-CF708B982365")!
    private let logID = UUID(uuidString: "EC8AB3F1-3AE1-4427-B68A-45A0C6275E19")!

    private func snapshot(
        habits: [UUID: Int],
        logs: [UUID: HabitReminderSyncState.Log] = [:],
        autoLinked: Set<UUID> = [],
        workoutSource: HabitReminderSyncState.WorkoutSource = .resolved(nil),
        generation: Int = 0
    ) -> HabitReminderSyncState.Snapshot {
        .init(habits: habits, logs: logs, autoLinkedHabitIDs: autoLinked,
              workoutSource: workoutSource,
              generation: generation)
    }

    @Test("Initial and forced generations refresh all habits")
    func forcedRefresh() {
        var state = HabitReminderSyncState()
        let initial = snapshot(habits: [first: 1, second: 1])
        #expect(state.plan(for: initial) == .init(habitIDs: [first, second], cleanUpOrphans: true))
        #expect(state.plan(for: initial) == .init(habitIDs: [], cleanUpOrphans: false))

        let forced = snapshot(habits: [first: 1, second: 1], generation: 1)
        #expect(state.plan(for: forced) == .init(habitIDs: [first, second], cleanUpOrphans: true))
    }

    @Test("Only changed habits and log owners refresh")
    func changedOwners() {
        var state = HabitReminderSyncState()
        let initial = snapshot(habits: [first: 1, second: 1],
                               logs: [logID: .init(habitID: first, signature: 1)])
        _ = state.plan(for: initial)
        let changedLog = snapshot(habits: [first: 1, second: 1],
                                  logs: [logID: .init(habitID: first, signature: 2)])
        #expect(state.plan(for: changedLog) == .init(habitIDs: [first], cleanUpOrphans: false))

        let changedHabit = snapshot(habits: [first: 1, second: 2],
                                    logs: [logID: .init(habitID: first, signature: 2)])
        #expect(state.plan(for: changedHabit) == .init(habitIDs: [second], cleanUpOrphans: false))

        let movedLog = snapshot(habits: [first: 1, second: 2],
                                logs: [logID: .init(habitID: second, signature: 2)])
        #expect(state.plan(for: movedLog) == .init(habitIDs: [first, second], cleanUpOrphans: false))
    }

    @Test("Log deletion refreshes its owner; habit deletion cleans orphans")
    func deletion() {
        var state = HabitReminderSyncState()
        _ = state.plan(for: snapshot(habits: [first: 1, second: 1],
                                    logs: [logID: .init(habitID: first, signature: 1)]))
        #expect(state.plan(for: snapshot(habits: [first: 1, second: 1])) ==
                .init(habitIDs: [first], cleanUpOrphans: false))
        #expect(state.plan(for: snapshot(habits: [first: 1])) ==
                .init(habitIDs: [], cleanUpOrphans: true))
    }

    @Test("Exercise existence changes refresh exercise-linked habits only")
    func exerciseChanges() {
        var state = HabitReminderSyncState()
        _ = state.plan(for: snapshot(habits: [first: 1, second: 1], autoLinked: [first]))
        let completed = snapshot(habits: [first: 1, second: 1], autoLinked: [first],
                                 workoutSource: .resolved(Date()))
        #expect(state.plan(for: completed) == .init(habitIDs: [first], cleanUpOrphans: false))

        #expect(state.plan(for: completed) == .init(habitIDs: [], cleanUpOrphans: false))

        let undone = snapshot(habits: [first: 1, second: 1], autoLinked: [first])
        #expect(state.plan(for: undone) == .init(habitIDs: [first], cleanUpOrphans: false))
    }

    @Test("Pending workout reads preserve linked requests while manual schedules refresh")
    func pendingWorkoutRead() {
        var state = HabitReminderSyncState()
        let initial = snapshot(habits: [first: 1, second: 1], autoLinked: [first], workoutSource: .pending)
        #expect(state.plan(for: initial) == .init(habitIDs: [second], cleanUpOrphans: true))

        let editedWhilePending = snapshot(habits: [first: 2, second: 1], autoLinked: [first], workoutSource: .pending)
        #expect(state.plan(for: editedWhilePending) == .init(habitIDs: [], cleanUpOrphans: false))

        let resolved = snapshot(habits: [first: 2, second: 1], autoLinked: [first])
        #expect(state.plan(for: resolved) == .init(habitIDs: [first], cleanUpOrphans: false))
    }
}
