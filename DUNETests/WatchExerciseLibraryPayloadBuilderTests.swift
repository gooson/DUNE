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
        primaryMuscles: [MuscleGroup] = [],
        cardioSecondaryUnit: CardioSecondaryUnit? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: name,
            category: category,
            inputType: inputType,
            primaryMuscles: primaryMuscles,
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
        let benchRecord = ExerciseRecord(
            date: defaultUpdatedAt.addingTimeInterval(300),
            exerciseType: "Bench Press",
            duration: 600,
            exerciseDefinitionID: "bench-press"
        )
        benchRecord.sets = [
            WorkoutSet(setNumber: 1, weight: 80, reps: 10, isCompleted: true),
            WorkoutSet(setNumber: 2, weight: 82.5, reps: 8, isCompleted: true),
        ]
        let tempoRecord = ExerciseRecord(
            date: mostRecentWorkout,
            exerciseType: "Tempo Bench Press",
            duration: 720,
            exerciseDefinitionID: "tempo-bench-press"
        )
        tempoRecord.sets = [
            WorkoutSet(setNumber: 1, weight: 85, reps: 6, isCompleted: true),
            WorkoutSet(setNumber: 2, weight: 87.5, reps: 5, isCompleted: true),
            WorkoutSet(setNumber: 3, weight: 90, reps: 4, isCompleted: true),
        ]
        let exerciseRecords = [benchRecord, tempoRecord]

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
        #expect(benchPayload.procedureSets?.count == 2)
        #expect(benchPayload.procedureSets?.first?.weight == 80)
        #expect(benchPayload.procedureUpdatedAt == benchRecord.date)
        #expect(benchPayload.progressionIncrementKg == 2.5)

        let tempoPayload = try #require(payload.first { $0.id == "tempo-bench-press" })
        #expect(tempoPayload.defaultReps == 5)
        #expect(tempoPayload.defaultWeightKg == 92.5)
        #expect(tempoPayload.isPreferred)
        #expect(tempoPayload.lastUsedAt == mostRecentWorkout)
        #expect(tempoPayload.usageCount == 2)
        #expect(tempoPayload.procedureSets?.count == 3)
        #expect(tempoPayload.procedureSets?.first?.weight == 85)
        #expect(tempoPayload.procedureUpdatedAt == tempoRecord.date)
        #expect(tempoPayload.progressionIncrementKg == 2.5)

        let runningPayload = try #require(payload.first { $0.id == "running" })
        #expect(runningPayload.defaultReps == nil)
        #expect(runningPayload.defaultWeightKg == nil)
        #expect(!runningPayload.isPreferred)
        #expect(runningPayload.lastUsedAt == nil)
        #expect(runningPayload.usageCount == 0)
        #expect(runningPayload.procedureSets == nil)
        #expect(runningPayload.procedureUpdatedAt == nil)
        #expect(runningPayload.progressionIncrementKg == nil)
    }

    @Test("payload falls back to standard strength defaults when persisted defaults are absent")
    func payloadFallsBackToStandardStrengthDefaults() throws {
        let squat = definition(
            id: "barbell-squat",
            name: "Squat",
            primaryMuscles: [.quadriceps, .glutes]
        )
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
        #expect(squatPayload.procedureSets == nil)
        #expect(squatPayload.progressionIncrementKg == 5.0)
    }

    @Test("defaults-only payload update preserves usage metadata from cached snapshot")
    func defaultsOnlyUpdatePreservesUsageMetadata() throws {
        let bench = definition(id: "bench-press", name: "Bench Press")
        let tempoBench = definition(id: "tempo-bench-press", name: "Tempo Bench Press")
        let library = MockLibrary(definitions: [bench, tempoBench])
        let lastUsedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let existingPayload = [
            WatchExerciseInfo(
                id: "bench-press",
                name: "Bench Press",
                inputType: ExerciseInputType.setsRepsWeight.rawValue,
                defaultSets: WorkoutDefaults.setCount,
                defaultReps: WorkoutDefaults.defaultReps,
                defaultWeightKg: nil,
                isPreferred: false,
                lastUsedAt: lastUsedAt,
                usageCount: 4,
                equipment: Equipment.barbell.rawValue,
                cardioSecondaryUnit: nil,
                procedureSets: [
                    WatchProcedureSetSnapshot(setNumber: 1, weight: 70, reps: 10),
                    WatchProcedureSetSnapshot(setNumber: 2, weight: 72.5, reps: 8),
                ],
                procedureUpdatedAt: lastUsedAt,
                progressionIncrementKg: 2.5
            ),
            WatchExerciseInfo(
                id: "tempo-bench-press",
                name: "Tempo Bench Press",
                inputType: ExerciseInputType.setsRepsWeight.rawValue,
                defaultSets: WorkoutDefaults.setCount,
                defaultReps: WorkoutDefaults.defaultReps,
                defaultWeightKg: nil,
                isPreferred: false,
                lastUsedAt: lastUsedAt,
                usageCount: 4,
                equipment: Equipment.barbell.rawValue,
                cardioSecondaryUnit: nil,
                procedureSets: [
                    WatchProcedureSetSnapshot(setNumber: 1, weight: 75, reps: 6),
                    WatchProcedureSetSnapshot(setNumber: 2, weight: 77.5, reps: 5),
                ],
                procedureUpdatedAt: lastUsedAt,
                progressionIncrementKg: 2.5
            ),
        ]

        let defaultRecords = [
            ExerciseDefaultRecord(
                exerciseDefinitionID: "tempo-bench-press",
                defaultWeight: 95,
                defaultReps: 5,
                isManualOverride: true,
                isPreferred: true,
                lastUsedDate: lastUsedAt.addingTimeInterval(60)
            )
        ]

        let payload = WatchExerciseLibraryPayloadBuilder.makePayload(
            definitions: library.definitions,
            defaultRecords: defaultRecords,
            retaining: existingPayload,
            library: library
        )

        let benchPayload = try #require(payload.first { $0.id == "bench-press" })
        #expect(benchPayload.defaultReps == 5)
        #expect(benchPayload.defaultWeightKg == 95)
        #expect(benchPayload.isPreferred)
        #expect(benchPayload.lastUsedAt == lastUsedAt)
        #expect(benchPayload.usageCount == 4)
        #expect(benchPayload.procedureSets?.count == 2)
        #expect(benchPayload.procedureSets?.first?.weight == 70)
        #expect(benchPayload.procedureUpdatedAt == lastUsedAt)
        #expect(benchPayload.progressionIncrementKg == 2.5)

        let tempoPayload = try #require(payload.first { $0.id == "tempo-bench-press" })
        #expect(tempoPayload.defaultReps == 5)
        #expect(tempoPayload.defaultWeightKg == 95)
        #expect(tempoPayload.isPreferred)
        #expect(tempoPayload.lastUsedAt == lastUsedAt)
        #expect(tempoPayload.usageCount == 4)
        #expect(tempoPayload.procedureSets?.count == 2)
        #expect(tempoPayload.procedureSets?.first?.weight == 75)
        #expect(tempoPayload.procedureUpdatedAt == lastUsedAt)
        #expect(tempoPayload.progressionIncrementKg == 2.5)
    }
}
