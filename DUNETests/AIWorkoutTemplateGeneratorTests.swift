import Foundation
import Testing
@testable import DUNE

private struct MockWorkoutGenerationLibrary: ExerciseLibraryQuerying {
    let exercises: [ExerciseDefinition]

    func allExercises() -> [ExerciseDefinition] {
        exercises
    }

    func exercise(byID id: String) -> ExerciseDefinition? {
        exercises.first { $0.id == id }
    }

    func search(query: String) -> [ExerciseDefinition] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter {
            $0.localizedName.localizedCaseInsensitiveContains(query)
                || $0.name.localizedCaseInsensitiveContains(query)
                || ($0.aliases ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition] {
        exercises.filter { $0.primaryMuscles.contains(muscle) || $0.secondaryMuscles.contains(muscle) }
    }

    func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition] {
        exercises.filter { $0.category == category }
    }

    func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition] {
        exercises.filter { $0.equipment == equipment }
    }
}

@Suite("AIWorkoutTemplateGenerator")
struct AIWorkoutTemplateGeneratorTests {
    private let sut = AIWorkoutTemplateGenerator()

    @Test("Returns unavailable error on simulator when Foundation Models are not available")
    func unavailableOnSimulator() async {
        let request = WorkoutTemplateGenerationRequest(prompt: "Build a shoulder workout")

        do {
            _ = try await sut.generateTemplate(from: request, library: makeLibrary())
            Issue.record("Expected workout generation to fail on simulator")
        } catch let error as WorkoutTemplateGenerationError {
            #expect(error == .unavailable)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Summarizes empty history with fallback line")
    func summarizesEmptyHistory() {
        let lines = sut.summarizeRecentHistory([], library: makeLibrary())

        #expect(lines == ["- No recent workout history was provided."])
    }

    @Test("Summarizes frequent recent exercises and recovered muscles")
    func summarizesRecentHistory() {
        let library = makeLibrary()
        let now = Date()
        let records = [
            ExerciseRecordSnapshot(
                date: now.addingTimeInterval(-86_400),
                exerciseDefinitionID: "dumbbell-shoulder-press",
                exerciseName: "Dumbbell Shoulder Press",
                primaryMuscles: [.shoulders],
                secondaryMuscles: [.triceps],
                completedSetCount: 4,
                totalWeight: 240,
                totalReps: 40
            ),
            ExerciseRecordSnapshot(
                date: now.addingTimeInterval(-3 * 86_400),
                exerciseDefinitionID: "push-up",
                exerciseName: "Push Up",
                primaryMuscles: [.chest],
                secondaryMuscles: [.triceps],
                completedSetCount: 3,
                totalReps: 45
            ),
            ExerciseRecordSnapshot(
                date: now.addingTimeInterval(-5 * 86_400),
                exerciseDefinitionID: "push-up",
                exerciseName: "Push Up",
                primaryMuscles: [.chest],
                secondaryMuscles: [.triceps],
                completedSetCount: 3,
                totalReps: 36
            ),
        ]

        let lines = sut.summarizeRecentHistory(records, library: library)

        #expect(lines.contains { $0.contains("Recent workout count: 3") })
        #expect(lines.contains { $0.contains("Push Up") })
    }

    @Test("Search tool returns exact catalog lines for matching strength exercises")
    func searchToolReturnsCatalogLines() async throws {
        let tool = AIWorkoutTemplateGenerator.SearchExerciseTool(library: makeLibrary())

        let output = try await tool.call(arguments: .init(query: "press"))

        #expect(output.contains("dumbbell-shoulder-press"))
        #expect(output.contains("Dumbbell Shoulder Press"))
        #expect(!output.contains("running"))
    }

    @Test("Resolve generated template filters unresolved, duplicate, and unsupported slots")
    func resolveGeneratedTemplateFiltersInvalidSlots() throws {
        let template = AIWorkoutTemplate(
            name: "Shoulder Builder",
            exercises: [
                AIExerciseSlot(
                    exerciseID: "dumbbell-shoulder-press",
                    exerciseName: "Dumbbell Shoulder Press",
                    sets: 4,
                    reps: 10
                ),
                AIExerciseSlot(
                    exerciseID: "dumbbell-shoulder-press",
                    exerciseName: "Dumbbell Shoulder Press",
                    sets: 3,
                    reps: 12
                ),
                AIExerciseSlot(
                    exerciseID: "running",
                    exerciseName: "Running",
                    sets: 1,
                    reps: 1
                ),
            ],
            estimatedMinutes: 30
        )

        let resolved = try sut.resolveGeneratedTemplate(template, library: makeLibrary())

        #expect(resolved.name == "Shoulder Builder")
        #expect(resolved.estimatedMinutes == 30)
        #expect(resolved.slots.count == 1)
        #expect(resolved.slots.first?.exerciseDefinitionID == "dumbbell-shoulder-press")
    }

    @Test("Resolve generated template fails when no supported exercises remain")
    func resolveGeneratedTemplateFailsWithoutValidExercises() {
        let template = AIWorkoutTemplate(
            name: "Cardio Only",
            exercises: [
                AIExerciseSlot(
                    exerciseID: "running",
                    exerciseName: "Running",
                    sets: 1,
                    reps: 1
                )
            ],
            estimatedMinutes: 25
        )

        do {
            _ = try sut.resolveGeneratedTemplate(template, library: makeLibrary())
            Issue.record("Expected noExercisesMatched error")
        } catch let error as WorkoutTemplateGenerationError {
            #expect(error == .noExercisesMatched)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makeLibrary() -> MockWorkoutGenerationLibrary {
        MockWorkoutGenerationLibrary(
            exercises: [
                makeExercise(
                    id: "dumbbell-shoulder-press",
                    name: "Dumbbell Shoulder Press",
                    aliases: ["Shoulder Press", "Overhead Press"],
                    category: .strength,
                    inputType: .setsRepsWeight,
                    primaryMuscles: [.shoulders],
                    secondaryMuscles: [.triceps],
                    equipment: .dumbbell
                ),
                makeExercise(
                    id: "push-up",
                    name: "Push Up",
                    aliases: ["Pushup", "Press Up"],
                    category: .bodyweight,
                    inputType: .setsReps,
                    primaryMuscles: [.chest],
                    secondaryMuscles: [.triceps],
                    equipment: .bodyweight
                ),
                makeExercise(
                    id: "running",
                    name: "Running",
                    aliases: ["Jogging"],
                    category: .cardio,
                    inputType: .durationDistance,
                    primaryMuscles: [.quadriceps],
                    secondaryMuscles: [.calves],
                    equipment: .bodyweight
                ),
            ]
        )
    }

    private func makeExercise(
        id: String,
        name: String,
        aliases: [String],
        category: ExerciseCategory,
        inputType: ExerciseInputType,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup],
        equipment: Equipment
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: name,
            category: category,
            inputType: inputType,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            metValue: 5.5,
            aliases: aliases,
            cardioSecondaryUnit: inputType == .durationDistance ? .km : nil
        )
    }
}
