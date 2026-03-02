import Foundation
import Testing
@testable import DUNEWatch

@Suite("WatchExerciseHelpers")
struct WatchExerciseHelpersTests {
    private func exercise(
        id: String,
        name: String = "Bench Press",
        defaultSets: Int = 3,
        defaultReps: Int? = 10,
        defaultWeightKg: Double? = 50
    ) -> WatchExerciseInfo {
        WatchExerciseInfo(
            id: id,
            name: name,
            inputType: "weight_reps",
            defaultSets: defaultSets,
            defaultReps: defaultReps,
            defaultWeightKg: defaultWeightKg,
            equipment: "barbell",
            cardioSecondaryUnit: nil
        )
    }

    @Test("exerciseSubtitle formats optional weight and applies bounds")
    func exerciseSubtitleFormatting() {
        #expect(exerciseSubtitle(sets: 3, reps: 10, weight: nil) == "3 sets · 10 reps")
        #expect(exerciseSubtitle(sets: 3, reps: 10, weight: 80) == "3 sets · 10 reps · 80.0kg")
        #expect(exerciseSubtitle(sets: 3, reps: 10, weight: 0) == "3 sets · 10 reps")
        #expect(exerciseSubtitle(sets: 3, reps: 10, weight: 501) == "3 sets · 10 reps")
    }

    @Test("uniqueByCanonical keeps first exercise for canonical duplicates")
    func uniqueByCanonicalKeepsFirst() {
        let runID = UUID().uuidString
        let first = exercise(id: "tempo-\(runID)-bench-press", name: "Tempo Bench")
        let duplicate = exercise(id: "\(runID)-bench-press", name: "Bench")
        let squat = exercise(id: "\(runID)-squat", name: "Squat")

        let result = uniqueByCanonical([first, duplicate, squat])
        #expect(result.count == 2)
        #expect(result[0].id == first.id)
        #expect(result[1].id == squat.id)
    }

    @Test("resolvedDefaults returns fallback reps when no defaults are present")
    func resolvedDefaultsFallback() {
        let runID = UUID().uuidString
        let noDefaults = exercise(
            id: "\(runID)-no-defaults",
            name: "No Defaults",
            defaultSets: 2,
            defaultReps: nil,
            defaultWeightKg: nil
        )

        let defaults = resolvedDefaults(for: noDefaults)
        #expect(defaults.reps == 10)
        #expect(defaults.weight == nil)
    }

    @Test("resolvedDefaults prefers latest set over exercise defaults")
    func resolvedDefaultsPrefersLatestSet() {
        let runID = UUID().uuidString
        let target = exercise(
            id: "\(runID)-squat",
            name: "Squat",
            defaultSets: 4,
            defaultReps: 12,
            defaultWeightKg: 60
        )
        RecentExerciseTracker.recordLatestSet(exerciseID: target.id, weight: 100, reps: 6)

        let defaults = resolvedDefaults(for: target)
        #expect(defaults.reps == 6)
        #expect(defaults.weight == 100)
    }

    @Test("snapshotFromExercise uses resolved defaults in template entry")
    func snapshotFromExerciseUsesResolvedDefaults() {
        let runID = UUID().uuidString
        let exerciseInfo = exercise(
            id: "tempo-\(runID)-deadlift-paused",
            name: "Deadlift",
            defaultSets: 4,
            defaultReps: 5,
            defaultWeightKg: 120
        )
        RecentExerciseTracker.recordLatestSet(
            exerciseID: "\(runID)-deadlift",
            weight: 130,
            reps: 3
        )

        let snapshot = snapshotFromExercise(exerciseInfo)
        #expect(snapshot.name == "Deadlift")
        #expect(snapshot.entries.count == 1)

        let entry = snapshot.entries[0]
        #expect(entry.exerciseDefinitionID == exerciseInfo.id)
        #expect(entry.defaultSets == 4)
        #expect(entry.defaultReps == 3)
        #expect(entry.defaultWeightKg == 130)
    }
}
