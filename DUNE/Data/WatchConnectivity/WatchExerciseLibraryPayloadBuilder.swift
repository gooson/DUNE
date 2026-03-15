import Foundation
import SwiftData

struct WatchExerciseSyncMetadata: Sendable, Equatable {
    struct Entry: Sendable, Equatable {
        var defaultReps: Int?
        var defaultWeightKg: Double?
        var isPreferred: Bool
        var lastUsedAt: Date?
        var usageCount: Int
        fileprivate var defaultsUpdatedAt: Date

        init(
            defaultReps: Int? = nil,
            defaultWeightKg: Double? = nil,
            isPreferred: Bool = false,
            lastUsedAt: Date? = nil,
            usageCount: Int = 0,
            defaultsUpdatedAt: Date = .distantPast
        ) {
            self.defaultReps = defaultReps
            self.defaultWeightKg = defaultWeightKg
            self.isPreferred = isPreferred
            self.lastUsedAt = lastUsedAt
            self.usageCount = usageCount
            self.defaultsUpdatedAt = defaultsUpdatedAt
        }
    }

    struct ProcedureEntry: Sendable, Equatable {
        var sets: [WatchProcedureSetSnapshot]
        var updatedAt: Date
    }

    var entriesByCanonicalID: [String: Entry]
    var procedureByExerciseID: [String: ProcedureEntry]

    static let empty = WatchExerciseSyncMetadata(entriesByCanonicalID: [:], procedureByExerciseID: [:])
}

enum WatchExerciseLibraryPayloadBuilder {
    static func makePayload(
        definitions: [ExerciseDefinition],
        defaultRecords: [ExerciseDefaultRecord],
        exerciseRecords: [ExerciseRecord],
        library: any ExerciseLibraryQuerying
    ) -> [WatchExerciseInfo] {
        let metadata = makeMetadata(
            defaultRecords: defaultRecords,
            exerciseRecords: exerciseRecords,
            library: library
        )

        return makePayload(
            definitions: definitions,
            metadata: metadata,
            retainedSnapshot: [:],
            library: library
        )
    }

    static func makePayload(
        definitions: [ExerciseDefinition],
        defaultRecords: [ExerciseDefaultRecord],
        retaining existingPayload: [WatchExerciseInfo],
        library: any ExerciseLibraryQuerying
    ) -> [WatchExerciseInfo] {
        let metadata = makeMetadata(
            defaultRecords: defaultRecords,
            exerciseRecords: [],
            library: library
        )
        let retainedSnapshot = Dictionary(
            uniqueKeysWithValues: existingPayload.map { ($0.id, $0) }
        )

        return makePayload(
            definitions: definitions,
            metadata: metadata,
            retainedSnapshot: retainedSnapshot,
            library: library
        )
    }

    static func makeMetadata(
        defaultRecords: [ExerciseDefaultRecord],
        exerciseRecords: [ExerciseRecord],
        library: any ExerciseLibraryQuerying
    ) -> WatchExerciseSyncMetadata {
        var entriesByCanonicalID: [String: WatchExerciseSyncMetadata.Entry] = [:]
        var procedureByExerciseID: [String: WatchExerciseSyncMetadata.ProcedureEntry] = [:]

        for record in defaultRecords {
            guard !record.exerciseDefinitionID.isEmpty else { continue }
            let canonicalID = canonicalID(for: record.exerciseDefinitionID, library: library)
            var entry = entriesByCanonicalID[canonicalID] ?? .init()
            entry.isPreferred = entry.isPreferred || record.isPreferred

            if record.lastUsedDate >= entry.defaultsUpdatedAt {
                entry.defaultReps = record.defaultReps
                entry.defaultWeightKg = record.defaultWeight
                entry.defaultsUpdatedAt = record.lastUsedDate
            }

            entriesByCanonicalID[canonicalID] = entry
        }

        let sortedRecords = exerciseRecords.sorted { $0.date > $1.date }
        for record in sortedRecords {
            guard let exerciseDefinitionID = record.exerciseDefinitionID,
                  !exerciseDefinitionID.isEmpty else {
                continue
            }

            if procedureByExerciseID[exerciseDefinitionID] == nil,
               let procedure = makeProcedureEntry(from: record) {
                procedureByExerciseID[exerciseDefinitionID] = procedure
            }
        }

        for record in exerciseRecords {
            guard let exerciseDefinitionID = record.exerciseDefinitionID,
                  !exerciseDefinitionID.isEmpty else {
                continue
            }

            let canonicalID = canonicalID(for: exerciseDefinitionID, library: library)
            var entry = entriesByCanonicalID[canonicalID] ?? .init()
            entry.usageCount += 1

            if let lastUsedAt = entry.lastUsedAt {
                if record.date > lastUsedAt {
                    entry.lastUsedAt = record.date
                }
            } else {
                entry.lastUsedAt = record.date
            }

            entriesByCanonicalID[canonicalID] = entry
        }

        return WatchExerciseSyncMetadata(
            entriesByCanonicalID: entriesByCanonicalID,
            procedureByExerciseID: procedureByExerciseID
        )
    }

    private static func canonicalID(
        for exerciseID: String,
        library: any ExerciseLibraryQuerying
    ) -> String {
        let representativeID = library.representativeExercise(byID: exerciseID)?.id ?? exerciseID
        return QuickStartCanonicalService.canonicalExerciseID(for: representativeID)
    }

    private static func defaultRepsFallback(for definition: ExerciseDefinition) -> Int? {
        switch definition.inputType {
        case .setsRepsWeight, .setsReps:
            WorkoutDefaults.defaultReps
        default:
            nil
        }
    }

    private static func makeProcedureEntry(
        from record: ExerciseRecord
    ) -> WatchExerciseSyncMetadata.ProcedureEntry? {
        let sets = record.completedSets.compactMap { set -> WatchProcedureSetSnapshot? in
            guard set.weight != nil || set.reps != nil else { return nil }
            return WatchProcedureSetSnapshot(
                setNumber: set.setNumber,
                weight: set.weight,
                reps: set.reps
            )
        }
        .sorted { $0.setNumber < $1.setNumber }

        guard !sets.isEmpty else { return nil }
        return WatchExerciseSyncMetadata.ProcedureEntry(sets: sets, updatedAt: record.date)
    }

    private static func progressionIncrementKg(for definition: ExerciseDefinition) -> Double? {
        switch definition.inputType {
        case .setsRepsWeight, .setsReps:
            break
        default:
            return nil
        }

        let lowerMuscles: Set<MuscleGroup> = [.quadriceps, .hamstrings, .glutes]
        if !Set(definition.primaryMuscles).intersection(lowerMuscles).isEmpty {
            return 5.0
        }

        switch definition.equipment {
        case .dumbbell, .kettlebell, .band, .trx, .medicineBall, .stabilityBall, .bodyweight, .other:
            return 1.0
        default:
            return 2.5
        }
    }

    private static func makePayload(
        definitions: [ExerciseDefinition],
        metadata: WatchExerciseSyncMetadata,
        retainedSnapshot: [String: WatchExerciseInfo],
        library: any ExerciseLibraryQuerying
    ) -> [WatchExerciseInfo] {
        definitions.map { definition in
            let canonicalID = canonicalID(for: definition.id, library: library)
            let entry = metadata.entriesByCanonicalID[canonicalID]
            let retained = retainedSnapshot[definition.id]
            let defaultReps = entry?.defaultReps ?? defaultRepsFallback(for: definition)
            let procedure = metadata.procedureByExerciseID[definition.id]
            let progressionIncrement = progressionIncrementKg(for: definition) ?? retained?.progressionIncrementKg

            return WatchExerciseInfo(
                id: definition.id,
                name: definition.localizedName,
                inputType: definition.inputType.rawValue,
                defaultSets: retained?.defaultSets ?? WorkoutDefaults.setCount,
                defaultReps: defaultReps,
                defaultWeightKg: entry?.defaultWeightKg,
                isPreferred: entry?.isPreferred ?? false,
                lastUsedAt: retained?.lastUsedAt ?? entry?.lastUsedAt,
                usageCount: retained?.usageCount ?? entry?.usageCount ?? 0,
                equipment: definition.equipment == .other ? nil : definition.equipment.rawValue,
                cardioSecondaryUnit: definition.cardioSecondaryUnit?.rawValue,
                aliases: definition.aliases,
                procedureSets: procedure?.sets ?? retained?.procedureSets,
                procedureUpdatedAt: procedure?.updatedAt ?? retained?.procedureUpdatedAt,
                progressionIncrementKg: progressionIncrement
            )
        }
    }
}
