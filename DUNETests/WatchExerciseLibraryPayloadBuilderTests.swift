import Foundation
import Testing
@testable import DUNE

@Suite("WatchExerciseLibraryPayloadBuilder")
struct WatchExerciseLibraryPayloadBuilderTests {
    private struct MockLibrary: ExerciseLibraryQuerying {
        let definitions: [ExerciseDefinition]

        func allExercises() -> [ExerciseDefinition] { definitions }

        func exercise(byID id: String) -> ExerciseDefinition? {
            definitions.first { $0.id == id }
        }

        func search(query: String) -> [ExerciseDefinition] { [] }

        func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition] { [] }

        func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition] { [] }

        func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition] { [] }
    }

    private func definition(
        id: String,
        name: String,
        category: ExerciseCategory = .strength,
        inputType: ExerciseInputType = .setsRepsWeight,
        equipment: Equipment = .barbell,
        cardioSecondaryUnit: CardioSecondaryUnit? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: name,
            category: category,
            inputType: inputType,
            primaryMuscles: [],
            secondaryMuscles: [],
            equipment: equipment,
            metValue: 5.0,
            cardioSecondaryUnit: cardioSecondaryUnit
        )
    }

    @Test("payload mirrors persisted recent history and defaults across canonical variants")
    func payloadMirrorsPersistedHistory() throws {
        let bench = definition(id: "bench-press", name: "Bench Press")
        let tempoBench = definition(id: "tempo-bench-press", name: "Tempo Bench Press")
        let running = definition(
            id: "running",
            name: "Running",
            category: .cardio,
            inputType: .durationDistance,
            equipment: .bodyweight,
            cardioSecondaryUnit: .km
        )
        let library = MockLibrary(definitions: [bench, tempoBench, running])

        let defaultUpdatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let mostRecentWorkout = defaultUpdatedAt.addingTimeInterval(1_800)
        let defaultRecords = [
            ExerciseDefaultRecord(
                exerciseDefinitionID: "tempo-bench-press",
                defaultWeight: 92.5,
                defaultReps: 5,
                isManualOverride: true,
                isPreferred: true,
                lastUsedDate: defaultUpdatedAt
            )
        ]
        let exerciseRecords = [
            ExerciseRecord(
                date: defaultUpdatedAt.addingTimeInterval(300),
                exerciseType: "Bench Press",
                duration: 600,
                exerciseDefinitionID: "bench-press"
            ),
            ExerciseRecord(
                date: mostRecentWorkout,
                exerciseType: "Tempo Bench Press",
                duration: 720,
                exerciseDefinitionID: "tempo-bench-press"
            )
        ]

        let payload = WatchExerciseLibraryPayloadBuilder.makePayload(
            definitions: library.definitions,
            defaultRecords: defaultRecords,
            exerciseRecords: exerciseRecords,
            library: library
        )

        let benchPayload = try #require(payload.first { $0.id == "bench-press" })
        #expect(benchPayload.defaultReps == 5)
        #expect(benchPayload.defaultWeightKg == 92.5)
        #expect(benchPayload.isPreferred)
        #expect(benchPayload.lastUsedAt == mostRecentWorkout)
        #expect(benchPayload.usageCount == 2)

        let tempoPayload = try #require(payload.first { $0.id == "tempo-bench-press" })
        #expect(tempoPayload.defaultReps == 5)
        #expect(tempoPayload.defaultWeightKg == 92.5)
        #expect(tempoPayload.isPreferred)
        #expect(tempoPayload.lastUsedAt == mostRecentWorkout)
        #expect(tempoPayload.usageCount == 2)

        let runningPayload = try #require(payload.first { $0.id == "running" })
        #expect(runningPayload.defaultReps == nil)
        #expect(runningPayload.defaultWeightKg == nil)
        #expect(!runningPayload.isPreferred)
        #expect(runningPayload.lastUsedAt == nil)
        #expect(runningPayload.usageCount == 0)
    }

    @Test("payload falls back to standard strength defaults when persisted defaults are absent")
    func payloadFallsBackToStandardStrengthDefaults() throws {
        let squat = definition(id: "barbell-squat", name: "Squat")
        let library = MockLibrary(definitions: [squat])

        let payload = WatchExerciseLibraryPayloadBuilder.makePayload(
            definitions: library.definitions,
            defaultRecords: [],
            exerciseRecords: [],
            library: library
        )

        let squatPayload = try #require(payload.first)
        #expect(squatPayload.defaultSets == WorkoutDefaults.setCount)
        #expect(squatPayload.defaultReps == WorkoutDefaults.defaultReps)
        #expect(squatPayload.defaultWeightKg == nil)
        #expect(squatPayload.lastUsedAt == nil)
        #expect(squatPayload.usageCount == 0)
    }
}
