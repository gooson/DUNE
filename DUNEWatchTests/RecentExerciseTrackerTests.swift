import Foundation
import Testing
@testable import DUNEWatch

@Suite("RecentExerciseTracker")
struct RecentExerciseTrackerTests {
    private func exercise(
        id: String,
        name: String,
        defaultSets: Int = 3,
        defaultReps: Int? = 10,
        defaultWeightKg: Double? = 40
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

    @Test("canonicalExerciseID strips known prefixes/suffixes")
    func canonicalExerciseIDStripsVariants() {
        #expect(
            RecentExerciseTracker.canonicalExerciseID(
                exerciseID: " tempo-barbell-row-isometric-hold "
            ) == "barbell-row"
        )
        #expect(RecentExerciseTracker.canonicalExerciseID(exerciseID: "") == "")
    }

    @Test("sorted keeps used exercises first and unused alphabetical")
    func sortedOrdersUsedThenAlphabetical() {
        let runID = UUID().uuidString
        let used = exercise(id: "\(runID)-used", name: "Used")
        let alpha = exercise(id: "\(runID)-alpha", name: "Alpha")
        let zulu = exercise(id: "\(runID)-zulu", name: "Zulu")

        RecentExerciseTracker.recordUsage(exerciseID: used.id)

        let result = RecentExerciseTracker.sorted([zulu, used, alpha])
        #expect(result.count == 3)
        #expect(result[0].id == used.id)
        #expect(result[1].name == "Alpha")
        #expect(result[2].name == "Zulu")
    }

    @Test("personalizedPopular ranks by canonical usage and fills fallback")
    func personalizedPopularRanksAndFallsBack() {
        let runID = UUID().uuidString
        let bench = exercise(id: "\(runID)-bench-press", name: "Bench Press")
        let tempoBench = exercise(id: "tempo-\(runID)-bench-press", name: "Tempo Bench Press")
        let squat = exercise(id: "\(runID)-squat", name: "Squat")

        RecentExerciseTracker.recordUsage(exerciseID: bench.id)
        RecentExerciseTracker.recordUsage(exerciseID: tempoBench.id)
        RecentExerciseTracker.recordUsage(exerciseID: tempoBench.id)

        let result = RecentExerciseTracker.personalizedPopular(
            from: [bench, tempoBench, squat],
            limit: 2
        )

        #expect(result.count == 2)
        #expect(result[0].id == tempoBench.id)
        #expect(result[1].id == squat.id)
    }

    @Test("latestSet prefers exact ID and falls back to canonical ID")
    func latestSetExactThenCanonicalFallback() {
        let runID = UUID().uuidString
        let exactID = "\(runID)-bench-press"
        let variantID = "tempo-\(runID)-bench-press-paused"
        let canonicalOnlyVariant = "pause-\(runID)-bench-press"

        RecentExerciseTracker.recordLatestSet(exerciseID: variantID, weight: 30, reps: 5)
        RecentExerciseTracker.recordLatestSet(exerciseID: exactID, weight: 80, reps: 10)

        let exact = RecentExerciseTracker.latestSet(exerciseID: exactID)
        #expect(exact?.weight == 80)
        #expect(exact?.reps == 10)

        let fallback = RecentExerciseTracker.latestSet(exerciseID: canonicalOnlyVariant)
        #expect(fallback?.weight == 80)
        #expect(fallback?.reps == 10)
    }
}
