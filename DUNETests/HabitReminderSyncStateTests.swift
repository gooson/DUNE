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
        exerciseExists: Bool = false,
        generation: Int = 0
    ) -> HabitReminderSyncState.Snapshot {
        .init(habits: habits, logs: logs, autoLinkedHabitIDs: autoLinked,
              todayExerciseExists: exerciseExists,
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
                                 exerciseExists: true)
        #expect(state.plan(for: completed) == .init(habitIDs: [first], cleanUpOrphans: false))

        #expect(state.plan(for: completed) == .init(habitIDs: [], cleanUpOrphans: false))

        let undone = snapshot(habits: [first: 1, second: 1], autoLinked: [first])
        #expect(state.plan(for: undone) == .init(habitIDs: [first], cleanUpOrphans: false))
    }

    @Test("Exercise date check uses the calendar day, including boundary changes")
    func exerciseDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 8)))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let tonight = try #require(calendar.date(byAdding: .hour, value: 12, to: today))
        #expect(!HabitReminderSyncState.exerciseExists(on: [yesterday], referenceDate: today,
                                                       calendar: calendar))
        #expect(HabitReminderSyncState.exerciseExists(on: [yesterday, tonight], referenceDate: today,
                                                      calendar: calendar))
    }
}
