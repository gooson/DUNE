import Foundation
import Testing
@testable import DUNEWatch

@Suite("Watch exercise drag reorder", .serialized)
@MainActor
struct WorkoutManagerReorderTests {
    @Test("Drag keeps sets, extras, skipped state, and current exercise with their entries")
    func reordersAssociatedWorkoutState() async throws {
        let manager = WorkoutManager.shared
        manager.reset()
        defer { manager.reset() }
        let entries = ["A", "B", "C", "D"].map {
            TemplateEntry(exerciseDefinitionID: $0, exerciseName: $0)
        }
        try await manager.startQuickWorkout(with: WorkoutSessionTemplate(name: "Reorder", entries: entries))
        manager.completeSet(weight: 10, reps: 5)
        manager.advanceToNextExercise()
        manager.addExtraSet()
        manager.skipExercise()

        manager.reorderExercises(moving: [entries[3].id], before: entries[1].id)

        #expect(manager.templateSnapshot?.entries.map(\.id) == [entries[0].id, entries[3].id, entries[1].id, entries[2].id])
        #expect(manager.completedSetsData[0].count == 1)
        #expect(manager.completedSetsData.dropFirst().allSatisfy { $0.isEmpty })
        #expect(manager.extraSetsPerExercise == [2: 1])
        #expect(manager.skippedExerciseIndices == [2])
        #expect(manager.currentEntry?.id == entries[2].id)
        #expect(manager.currentExerciseIndex == 3)

        manager.reorderExercises(moving: [entries[3].id], before: entries[0].id)
        #expect(manager.templateSnapshot?.entries.first?.id == entries[0].id)
    }

    @Test("Moves multiple source IDs in displayed order before the destination")
    func reordersMultipleSources() throws {
        let ids = (0..<5).map { _ in UUID() }
        let result = try #require(WorkoutManager.reorderedExerciseIDs(
            ids, completedIndices: [], moving: [ids[3], ids[1]], before: ids[4]
        ))
        #expect(result == [ids[0], ids[2], ids[1], ids[3], ids[4]])
    }

    @Test("Keeps completed exercise in its original slot")
    func completedExerciseIsFixed() {
        let ids = (0..<4).map { _ in UUID() }
        #expect(WorkoutManager.reorderedExerciseIDs(
            ids, completedIndices: [1], moving: [ids[2]], before: ids[0]
        ) == nil)
        #expect(WorkoutManager.reorderedExerciseIDs(
            ids, completedIndices: [1], moving: [ids[1]], before: nil
        ) == nil)
        #expect(WorkoutManager.reorderedExerciseIDs(
            ids, completedIndices: [1], moving: [ids[3]], before: ids[2]
        ) == [ids[0], ids[1], ids[3], ids[2]])
        #expect(WorkoutManager.reorderedExerciseIDs(
            ids, completedIndices: [2], moving: [ids[0]], before: ids[2]
        ) == [ids[1], ids[0], ids[2], ids[3]])
    }

    @Test("Rejects unknown and duplicate drag IDs")
    func rejectsInvalidSources() {
        let ids = (0..<3).map { _ in UUID() }
        #expect(WorkoutManager.reorderedExerciseIDs(
            ids, completedIndices: [], moving: [ids[0], ids[0]], before: nil
        ) == nil)
        #expect(WorkoutManager.reorderedExerciseIDs(
            ids, completedIndices: [], moving: [UUID()], before: nil
        ) == nil)
        #expect(WorkoutManager.reorderedExerciseIDs(
            ids, completedIndices: [], moving: [ids[0]], before: UUID()
        ) == nil)
    }
}
