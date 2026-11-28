import Foundation
import SwiftData

@Model
final class WorkoutSet {
    var id: UUID = UUID()
    var exerciseRecord: ExerciseRecord?
    var setNumber: Int = 0
    var setTypeRaw: String = SetType.working.rawValue
    var weight: Double?
    var reps: Int?
    var duration: TimeInterval?
    var distance: Double?
    var intensity: Int? = nil
    var isCompleted: Bool = false
    var restDuration: TimeInterval?
    var rpe: Double? = nil
    /// Planned target; `reps` remains the actual performed count.
    var plannedReps: Int?
    /// `user` or `estimated`. nil means the source is unknown for legacy sets.
    var rpeSourceRaw: String?

    init(
        setNumber: Int = 0,
        setType: SetType = .working,
        weight: Double? = nil,
        reps: Int? = nil,
        duration: TimeInterval? = nil,
        distance: Double? = nil,
        intensity: Int? = nil,
        isCompleted: Bool = false,
        restDuration: TimeInterval? = nil,
        rpe: Double? = nil,
        plannedReps: Int? = nil,
        rpeSourceRaw: String? = nil
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.setTypeRaw = setType.rawValue
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.distance = distance
        self.intensity = intensity
        self.isCompleted = isCompleted
        self.restDuration = restDuration
        self.rpe = rpe
        self.plannedReps = plannedReps
        self.rpeSourceRaw = rpeSourceRaw
    }

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }
}

extension WorkoutStrengthArchive {
    init?(record: ExerciseRecord) {
        let entries = record.completedSets.map { set in
            SetEntry(
                id: set.id, number: set.setNumber, type: set.setTypeRaw,
                weight: set.weight, reps: set.reps, duration: set.duration,
                distance: set.distance, intensity: set.intensity, restDuration: set.restDuration,
                rpe: set.rpe, plannedReps: set.plannedReps, rpeSource: set.rpeSourceRaw
            )
        }
        guard !entries.isEmpty else { return nil }
        self.init(recordID: record.id, exerciseDefinitionID: record.exerciseDefinitionID, sets: entries)
    }

    /// Transient presentation values; the HealthKit workout remains the authoritative record.
    func displaySets() -> [WorkoutSet] {
        sets.map { entry in
            let set = WorkoutSet(
                setNumber: entry.number, weight: entry.weight, reps: entry.reps,
                duration: entry.duration, distance: entry.distance, intensity: entry.intensity,
                isCompleted: true, restDuration: entry.restDuration, rpe: entry.rpe,
                plannedReps: entry.plannedReps, rpeSourceRaw: entry.rpeSource
            )
            set.id = entry.id
            set.setTypeRaw = entry.type
            return set
        }
    }
}
