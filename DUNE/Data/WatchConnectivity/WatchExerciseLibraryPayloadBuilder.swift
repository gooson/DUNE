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

    var entriesByCanonicalID: [String: Entry]

    static let empty = WatchExerciseSyncMetadata(entriesByCanonicalID: [:])
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

        return WatchExerciseSyncMetadata(entriesByCanonicalID: entriesByCanonicalID)
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
                aliases: definition.aliases
            )
        }
    }
}
