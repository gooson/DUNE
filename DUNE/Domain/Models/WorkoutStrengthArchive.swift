import Foundation

/// DUNE-owned HealthKit workouts can carry the completed sets that produced the workout.
struct WorkoutStrengthArchive: Codable, Sendable {
    static let metadataKey = "com.dune.workout.completedSets.v1"

    struct SetEntry: Codable, Sendable, Hashable {
        let id: UUID
        let number: Int
        let type: String
        let weight: Double?
        let reps: Int?
        let duration: TimeInterval?
        let distance: Double?
        let intensity: Int?
        let restDuration: TimeInterval?
        let rpe: Double?
        let plannedReps: Int?
        let rpeSource: String?
    }

    let recordID: UUID
    let exerciseDefinitionID: String?
    let sets: [SetEntry]

    private static let maximumBytes = 256 * 1024

    init(recordID: UUID, exerciseDefinitionID: String?, sets: [SetEntry]) {
        self.recordID = recordID
        self.exerciseDefinitionID = exerciseDefinitionID
        self.sets = sets
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        recordID = try values.decode(UUID.self, forKey: .recordID)
        exerciseDefinitionID = try values.decodeIfPresent(String.self, forKey: .exerciseDefinitionID)
        sets = try values.decode([SetEntry].self, forKey: .sets)
        guard isValid else {
            throw DecodingError.dataCorruptedError(forKey: .sets, in: values, debugDescription: "Invalid completed sets")
        }
    }

    private var isValid: Bool {
        guard !sets.isEmpty, sets.count <= 512,
              Set(sets.map(\.id)).count == sets.count else { return false }
        return sets.allSatisfy { set in
            set.number >= 0 && (0...100_000).contains(set.reps ?? 0) &&
                [set.weight, set.duration, set.distance, set.restDuration, set.rpe]
                .compactMap { $0 }.allSatisfy { $0.isFinite && $0 >= 0 }
        }
    }

    func encodedMetadata() -> String? {
        guard isValid, let data = try? JSONEncoder().encode(self),
              data.count <= Self.maximumBytes else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func read(from metadata: [String: Any]?, isDUNEWorkout: Bool) -> Self? {
        guard isDUNEWorkout, let value = metadata?[metadataKey] as? String,
              value.utf8.count <= maximumBytes,
              !value.isEmpty else { return nil }
        return try? JSONDecoder().decode(Self.self, from: Data(value.utf8))
    }
}

/// A sticky, device-local diagnostic. This preference contains no workout identifiers or health values.
enum WorkoutBackupWarning {
    static let key = "workoutBackupIncomplete"

    static func record(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }
}

extension WorkoutBackupWarning {
    /// HealthKit workouts are immutable after finalization. Attempt enrichment exactly once.
    /// If rejected, preserve the base workout and leave the incomplete-backup status visible.
    static func attach(
        archive: WorkoutStrengthArchive?, place: WorkoutPlace?,
        isolation: isolated (any Actor)? = #isolation,
        write: ([String: String]) async throws -> Void,
        markIncomplete: () -> Void = { record() }
    ) async throws {
        var metadata: [String: String] = [:]
        if let archive {
            if let value = archive.encodedMetadata() {
                metadata[WorkoutStrengthArchive.metadataKey] = value
            } else {
                markIncomplete()
            }
        }
        if let place {
            if let value = WorkoutPlaceMetadata.encodedValue(for: place) {
                metadata[WorkoutPlaceMetadata.key] = value
            } else {
                markIncomplete()
            }
        }
        guard !metadata.isEmpty else { return }
        do {
            try await write(metadata)
        } catch {
            try Task.checkCancellation()
            markIncomplete()
        }
    }
}
