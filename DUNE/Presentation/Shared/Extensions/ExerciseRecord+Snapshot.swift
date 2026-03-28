import Foundation

extension ExerciseRecord {
    func snapshot(library: ExerciseLibraryQuerying) -> ExerciseRecordSnapshot {
        var primary = primaryMuscles
        var secondary = secondaryMuscles

        let definition: ExerciseDefinition?
        if primary.isEmpty,
           let exerciseDefinitionID,
           let resolved = library.exercise(byID: exerciseDefinitionID) {
            primary = resolved.primaryMuscles
            secondary = resolved.secondaryMuscles
            definition = resolved
        } else if let exerciseDefinitionID {
            definition = library.exercise(byID: exerciseDefinitionID)
        } else {
            definition = nil
        }

        let completedSets = self.completedSets
        let totalWeight = completedSets.reduce(0.0) { total, set in
            let w = set.weight ?? 0
            let r = Double(set.reps ?? 0)
            guard w > 0, r > 0 else { return total }
            return total + w * r
        }
        let totalReps = completedSets.compactMap(\.reps).reduce(0, +)
        let durationMinutes = duration > 0 ? min(duration / 60.0, 480) : nil
        let distanceKm = distance.flatMap { $0 > 0 ? min($0 / 1000.0, 500) : nil }

        return ExerciseRecordSnapshot(
            date: date,
            exerciseDefinitionID: exerciseDefinitionID,
            exerciseName: definition?.localizedName ?? definition?.name ?? exerciseType,
            primaryMuscles: primary,
            secondaryMuscles: secondary,
            completedSetCount: completedSets.count,
            totalWeight: totalWeight > 0 ? totalWeight : nil,
            totalReps: totalReps > 0 ? totalReps : nil,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm
        )
    }
}
