import Foundation

// MARK: - Shared Exercise Helpers
// Used by CarouselHomeView and QuickStartAllExercisesView.
// Extracted per Correction #37/#167 to prevent drift between copies.

/// Builds subtitle: "3 sets · 10 reps" or "3 sets · 10 reps · 80.0kg"
func exerciseSubtitle(sets: Int, reps: Int, weight: Double?) -> String {
    var parts = "\(sets) sets · \(reps) reps"
    if let w = weight, w > 0, w <= 500 {
        parts += " · \(w.formattedWeight)kg"
    }
    return parts
}

/// Deduplicates exercises by canonical ID, keeping first occurrence.
func uniqueByCanonical(_ exercises: [WatchExerciseInfo]) -> [WatchExerciseInfo] {
    var seen = Set<String>()
    return exercises.filter { exercise in
        let canonical = RecentExerciseTracker.canonicalExerciseID(exerciseID: exercise.id)
        return seen.insert(canonical).inserted
    }
}

/// Resolves weight/reps defaults from latest set or exercise defaults.
func resolvedDefaults(for exercise: WatchExerciseInfo) -> (weight: Double?, reps: Int) {
    let latest = RecentExerciseTracker.latestSet(exerciseID: exercise.id)
    let reps = latest?.reps ?? exercise.defaultReps ?? 10
    let weight = latest?.weight ?? exercise.defaultWeightKg
    return (weight: weight, reps: reps)
}

/// Creates a single-exercise template snapshot for navigation.
func snapshotFromExercise(_ exercise: WatchExerciseInfo) -> WorkoutSessionTemplate {
    let defaults = resolvedDefaults(for: exercise)
    let entry = TemplateEntry(
        exerciseDefinitionID: exercise.id,
        exerciseName: exercise.name,
        defaultSets: exercise.defaultSets,
        defaultReps: defaults.reps,
        defaultWeightKg: defaults.weight,
        equipment: exercise.equipment
    )
    return WorkoutSessionTemplate(
        name: exercise.name,
        entries: [entry]
    )
}
