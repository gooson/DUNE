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
        #expect(output.contains("덤벨 숄더 프레스"))
        #expect(!output.contains("running"))
    }

    @Test("Search tool expands broad Korean muscle prompts into template-capable matches")
    func searchToolExpandsKoreanMusclePrompt() async throws {
        let tool = AIWorkoutTemplateGenerator.SearchExerciseTool(library: makeLibrary())

        let output = try await tool.call(arguments: .init(query: "어깨 운동 만들어줘"))

        #expect(output.contains("dumbbell-shoulder-press"))
        #expect(output.contains("덤벨 숄더 프레스"))
        #expect(!output.contains("running"))
    }

    @Test("Search tool prefers home-friendly bodyweight matches for home prompts")
    func searchToolPrefersHomeFriendlyMatches() async throws {
        let tool = AIWorkoutTemplateGenerator.SearchExerciseTool(library: makeLibrary())

        let output = try await tool.call(arguments: .init(query: "집에서 맨몸 상체 운동"))

        #expect(output.contains("push-up"))
        #expect(output.contains("푸시업"))
        #expect(!output.contains("machine-chest-press"))
    }

    @Test("Search tool excludes unsupported flexibility and HIIT exercise types")
    func searchToolExcludesUnsupportedExerciseTypes() async throws {
        let tool = AIWorkoutTemplateGenerator.SearchExerciseTool(library: makeLibrary())

        let flexibilityOutput = try await tool.call(arguments: .init(query: "mobility"))
        #expect(flexibilityOutput == "This request focuses on workout styles that the template builder cannot save yet.")
        #expect(!flexibilityOutput.contains("hip-mobility"))

        let hiitOutput = try await tool.call(arguments: .init(query: "burpee"))
        #expect(hiitOutput == "This request focuses on workout styles that the template builder cannot save yet.")
        #expect(!hiitOutput.contains("burpee-intervals"))
    }

    @Test("Preflight rejects ambiguous prompt before generation")
    func preflightRejectsAmbiguousPrompt() {
        let intent = AIWorkoutTemplateGenerator.promptIntent(for: "운동 추천해줘")

        #expect(AIWorkoutTemplateGenerator.preflightError(for: intent) == .ambiguousPrompt)
    }

    @Test("Preflight rejects unsupported prompt before generation")
    func preflightRejectsUnsupportedPrompt() {
        let intent = AIWorkoutTemplateGenerator.promptIntent(for: "mobility routine")

        #expect(AIWorkoutTemplateGenerator.preflightError(for: intent) == .unsupportedRequest)
    }

    @Test("Resolve generated template filters unresolved and duplicate slots while keeping cardio")
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
        #expect(resolved.slots.count == 2)
        #expect(resolved.slots.map(\.exerciseDefinitionID) == ["dumbbell-shoulder-press", "running"])
    }

    @Test("Resolve generated template normalizes cardio slots to 1 set and 1 rep")
    func resolveGeneratedTemplateNormalizesCardioSlots() throws {
        let template = AIWorkoutTemplate(
            name: "Cardio Only",
            exercises: [
                AIExerciseSlot(
                    exerciseID: "running",
                    exerciseName: "Running",
                    sets: 4,
                    reps: 12
                )
            ],
            estimatedMinutes: 25
        )

        let resolved = try sut.resolveGeneratedTemplate(template, library: makeLibrary())

        #expect(resolved.slots.count == 1)
        #expect(resolved.slots[0].exerciseDefinitionID == "running")
        #expect(resolved.slots[0].sets == 1)
        #expect(resolved.slots[0].reps == 1)
    }

    @Test("Resolve generated template still rejects unsupported non-template exercise types")
    func resolveGeneratedTemplateRejectsUnsupportedExerciseTypes() {
        let template = AIWorkoutTemplate(
            name: "Mobility Flow",
            exercises: [
                AIExerciseSlot(
                    exerciseID: "hip-mobility",
                    exerciseName: "Hip Mobility",
                    sets: 3,
                    reps: 10
                )
            ],
            estimatedMinutes: 20
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

    @Test("Resolve generated template rejects unsupported rounds-based exercise types")
    func resolveGeneratedTemplateRejectsRoundsBasedExerciseTypes() {
        let template = AIWorkoutTemplate(
            name: "Burpee Burner",
            exercises: [
                AIExerciseSlot(
                    exerciseID: "burpee-intervals",
                    exerciseName: "Burpee Intervals",
                    sets: 5,
                    reps: 10
                )
            ],
            estimatedMinutes: 18
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

    @Test("Resolve exercise rejects ambiguous exact-name matches")
    func resolveExerciseRejectsAmbiguousExactMatches() {
        let ambiguousLibrary = MockWorkoutGenerationLibrary(
            exercises: [
                makeExercise(
                    id: "barbell-shoulder-press",
                    name: "Barbell Shoulder Press",
                    aliases: ["Shoulder Press"],
                    category: .strength,
                    inputType: .setsRepsWeight,
                    primaryMuscles: [.shoulders],
                    secondaryMuscles: [.triceps],
                    equipment: .barbell
                ),
                makeExercise(
                    id: "dumbbell-shoulder-press-2",
                    name: "Dumbbell Shoulder Press",
                    aliases: ["Shoulder Press"],
                    category: .strength,
                    inputType: .setsRepsWeight,
                    primaryMuscles: [.shoulders],
                    secondaryMuscles: [.triceps],
                    equipment: .dumbbell
                ),
            ]
        )

        let resolved = sut.resolveExercise(
            exerciseID: "",
            exerciseName: "Shoulder Press",
            library: ambiguousLibrary
        )

        #expect(resolved == nil)
    }

    @Test("Resolve exercise rejects ambiguous fuzzy matches")
    func resolveExerciseRejectsAmbiguousFuzzyMatches() {
        let resolved = sut.resolveExercise(
            exerciseID: "",
            exerciseName: "press",
            library: makeLibrary()
        )

        #expect(resolved == nil)
    }

    private func makeLibrary() -> MockWorkoutGenerationLibrary {
        MockWorkoutGenerationLibrary(
            exercises: [
                makeExercise(
                    id: "dumbbell-shoulder-press",
                    name: "Dumbbell Shoulder Press",
                    localizedName: "덤벨 숄더 프레스",
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
                    localizedName: "푸시업",
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
                    localizedName: "러닝",
                    aliases: ["Jogging"],
                    category: .cardio,
                    inputType: .durationDistance,
                    primaryMuscles: [.quadriceps],
                    secondaryMuscles: [.calves],
                    equipment: .bodyweight
                ),
                makeExercise(
                    id: "hip-mobility",
                    name: "Hip Mobility",
                    localizedName: "힙 모빌리티",
                    aliases: ["Mobility Flow", "Stretching"],
                    category: .flexibility,
                    inputType: .durationIntensity,
                    primaryMuscles: [.glutes],
                    secondaryMuscles: [.hamstrings],
                    equipment: .bodyweight
                ),
                makeExercise(
                    id: "burpee-intervals",
                    name: "Burpee Intervals",
                    localizedName: "버피 인터벌",
                    aliases: ["Burpee Circuit", "HIIT Burpees"],
                    category: .hiit,
                    inputType: .roundsBased,
                    primaryMuscles: [.quadriceps],
                    secondaryMuscles: [.shoulders],
                    equipment: .bodyweight
                ),
                makeExercise(
                    id: "machine-chest-press",
                    name: "Chest Press Machine",
                    localizedName: "체스트 프레스 머신",
                    aliases: ["Chest Press"],
                    category: .strength,
                    inputType: .setsRepsWeight,
                    primaryMuscles: [.chest],
                    secondaryMuscles: [.triceps],
                    equipment: .machine
                ),
            ]
        )
    }

    private func makeExercise(
        id: String,
        name: String,
        localizedName: String? = nil,
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
            localizedName: localizedName ?? name,
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
