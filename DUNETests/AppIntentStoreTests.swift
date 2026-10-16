import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("App Intent persistence", .serialized)
@MainActor
struct AppIntentStoreTests {
    private func makeStore(
        saveContext: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> (DUNEAppIntentStore, ModelContainer) {
        let container = try ModelContainer(
            for: HabitDefinition.self, HabitLog.self, WorkoutTemplate.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = DUNEAppIntentStore(saveContext: saveContext)
        store.configure(container: container)
        return (store, container)
    }

    private func makeHabit(
        type: HabitType = .check,
        frequency: HabitFrequency = .daily,
        isAutoLinked: Bool = false
    ) -> HabitDefinition {
        HabitDefinition(
            name: "Water",
            iconCategory: .hydration,
            habitType: type,
            goalValue: 1,
            goalUnit: nil,
            frequency: frequency,
            isAutoLinked: isAutoLinked
        )
    }

    @Test("A manual check habit is completed at most once per local calendar day")
    func completionIsIdempotent() throws {
        let (store, container) = try makeStore()
        let habit = makeHabit()
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let now = Date()
        #expect(try store.completeHabit(id: habit.id, at: now) == .completed)
        #expect(try store.completeHabit(id: habit.id, at: now) == .alreadyCompleted)
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        #expect(try store.completeHabit(id: habit.id, at: tomorrow) == .completed)

        let logs = try container.mainContext.fetch(FetchDescriptor<HabitLog>())
        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.value == 1 && $0.habitDefinition?.id == habit.id })
    }

    @Test("A failed save cannot make a retry appear completed")
    func failedSaveDoesNotPoisonRetry() throws {
        enum InjectedError: Error { case saveFailed }
        var failNextSave = true
        let (store, container) = try makeStore(saveContext: { context in
            if failNextSave {
                failNextSave = false
                throw InjectedError.saveFailed
            }
            try context.save()
        })
        let habit = makeHabit()
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let now = Date()
        #expect(throws: InjectedError.self) {
            try store.completeHabit(id: habit.id, at: now)
        }
        #expect(try container.mainContext.fetch(FetchDescriptor<HabitLog>()).isEmpty)
        #expect(try store.completeHabit(id: habit.id, at: now) == .completed)
        #expect(try store.completeHabit(id: habit.id, at: now) == .alreadyCompleted)
        #expect(try container.mainContext.fetch(FetchDescriptor<HabitLog>()).count == 1)
    }

    @Test("Only active manual check habits are exposed and writable")
    func ineligibleHabitsAreRejected() throws {
        let (store, container) = try makeStore()
        let accepted = makeHabit()
        let archived = makeHabit()
        archived.isArchived = true
        let autoLinked = makeHabit(isAutoLinked: true)
        let interval = makeHabit(frequency: .interval(days: 2))
        let count = makeHabit(type: .count)
        let duration = makeHabit(type: .duration)
        for habit in [accepted, archived, autoLinked, interval, count, duration] {
            container.mainContext.insert(habit)
        }
        try container.mainContext.save()

        #expect(try store.manualCheckHabits().map(\.id) == [accepted.id])
        for habit in [archived, autoLinked, interval, count, duration] {
            #expect(throws: DUNEAppIntentError.self) {
                try store.completeHabit(id: habit.id)
            }
        }
        #expect(throws: DUNEAppIntentError.self) {
            try store.completeHabit(id: UUID())
        }
        #expect(try container.mainContext.fetch(FetchDescriptor<HabitLog>()).isEmpty)
    }

    @Test("Only nonempty saved workout templates are available to the open intent")
    func workoutTemplateQuery() throws {
        let (store, container) = try makeStore()
        let nonempty = WorkoutTemplate(name: "Strength", exerciseEntries: [
            TemplateEntry(exerciseDefinitionID: "squat", exerciseName: "Squat")
        ])
        let empty = WorkoutTemplate(name: "Empty")
        container.mainContext.insert(nonempty)
        container.mainContext.insert(empty)
        try container.mainContext.save()

        #expect(try store.workoutTemplates().map(\.id) == [nonempty.id])
        #expect(try store.workoutTemplates(for: [empty.id]).isEmpty)
        try store.validateWorkoutTemplate(id: nonempty.id)
        #expect(throws: DUNEAppIntentError.self) {
            try store.validateWorkoutTemplate(id: empty.id)
        }
    }
}
