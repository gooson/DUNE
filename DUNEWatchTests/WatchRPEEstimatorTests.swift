import Foundation
import Testing
@testable import DUNEWatch

@Suite("WatchRPEEstimator")
struct WatchRPEEstimatorTests {
    let estimator = WatchRPEEstimator()

    // MARK: - Nil Returns (Silent Skip)

    @Test("returns nil when no completed sets")
    func nilForEmptySets() {
        let result = estimator.estimateRPE(weight: 100, reps: 8, completedSets: [])
        #expect(result == nil)
    }

    @Test("returns nil for bodyweight exercise (weight = 0)")
    func nilForBodyweight() {
        let sets = [makeSet(weight: 80, reps: 10)]
        let result = estimator.estimateRPE(weight: 0, reps: 10, completedSets: sets)
        #expect(result == nil)
    }

    @Test("returns nil for zero reps")
    func nilForZeroReps() {
        let sets = [makeSet(weight: 80, reps: 10)]
        let result = estimator.estimateRPE(weight: 100, reps: 0, completedSets: sets)
        #expect(result == nil)
    }

    @Test("returns nil when all completed sets have zero weight")
    func nilForAllZeroWeightSets() {
        let sets = [makeSet(weight: 0, reps: 10), makeSet(weight: 0, reps: 8)]
        let result = estimator.estimateRPE(weight: 50, reps: 8, completedSets: sets)
        #expect(result == nil)
    }

    // MARK: - Basic 1RM% → RPE Mapping

    @Test("high %1RM maps to RPE 10")
    func highPercentageMapsToRPE10() {
        // Set 1: 100kg × 5 → 1RM ≈ 116.7
        // Set 2: 115kg × 1 → %1RM = 115/116.7 ≈ 0.985 → RPE 10
        let sets = [makeSet(weight: 100, reps: 5)]
        let result = estimator.estimateRPE(weight: 115, reps: 1, completedSets: sets)
        #expect(result == 10.0)
    }

    @Test("moderate %1RM maps to RPE 7-8")
    func moderatePercentage() {
        // Set 1: 100kg × 10 → 1RM ≈ 133.3
        // Set 2: 110kg × 8 → %1RM = 110/133.3 ≈ 0.825 → RPE 7.5
        let sets = [makeSet(weight: 100, reps: 10)]
        let result = estimator.estimateRPE(weight: 110, reps: 8, completedSets: sets)
        #expect(result == 7.5)
    }

    @Test("low %1RM maps to RPE 6")
    func lowPercentage() {
        // Set 1: 100kg × 10 → 1RM ≈ 133.3
        // Set 2: 80kg × 10 → %1RM = 80/133.3 ≈ 0.60 → RPE 6.0
        let sets = [makeSet(weight: 100, reps: 10)]
        let result = estimator.estimateRPE(weight: 80, reps: 10, completedSets: sets)
        #expect(result == 6.0)
    }

    // MARK: - Reps Degradation Correction

    @Test("adds 0.5 RPE when reps decrease vs last set")
    func repsDegradationCorrection() {
        // Set 1: 100kg × 10 → 1RM ≈ 133.3
        // Set 2: 100kg × 8 → %1RM = 100/133.3 ≈ 0.75 → base RPE 7.0
        // Reps decreased (10 → 8) → +0.5 → RPE 7.5
        let sets = [makeSet(weight: 100, reps: 10)]
        let result = estimator.estimateRPE(weight: 100, reps: 8, completedSets: sets)
        #expect(result == 7.5)
    }

    @Test("no correction when reps stay same")
    func noCorrectWhenRepsSame() {
        // Set 1: 100kg × 10 → 1RM ≈ 133.3
        // Set 2: 100kg × 10 → %1RM = 0.75 → RPE 7.0 (no correction)
        let sets = [makeSet(weight: 100, reps: 10)]
        let result = estimator.estimateRPE(weight: 100, reps: 10, completedSets: sets)
        #expect(result == 7.0)
    }

    @Test("no correction when reps increase")
    func noCorrectWhenRepsIncrease() {
        let sets = [makeSet(weight: 100, reps: 8)]
        let result = estimator.estimateRPE(weight: 100, reps: 10, completedSets: sets)
        // reps increased → no +0.5
        #expect(result != nil)
        // Should not have degradation bonus
        let setsReversed = [makeSet(weight: 100, reps: 10)]
        let resultWithDegrade = estimator.estimateRPE(weight: 100, reps: 8, completedSets: setsReversed)
        // The result with degradation should be higher
        #expect(resultWithDegrade! > result!)
    }

    // MARK: - Best 1RM Selection

    @Test("uses best 1RM from multiple sets")
    func bestOneRMFromMultipleSets() {
        // Set 1: 80kg × 10 → 1RM ≈ 106.7
        // Set 2: 100kg × 5 → 1RM ≈ 116.7 (best)
        // Current: 90kg × 8 → %1RM = 90/116.7 ≈ 0.771 → RPE 7.0
        let sets = [makeSet(weight: 80, reps: 10), makeSet(weight: 100, reps: 5)]
        let result = estimator.estimateRPE(weight: 90, reps: 8, completedSets: sets)
        #expect(result == 7.0)
    }

    // MARK: - Boundary Values

    @Test("result is always between 6.0 and 10.0")
    func resultWithinBounds() {
        let sets = [makeSet(weight: 100, reps: 10)]
        // Very light weight
        let low = estimator.estimateRPE(weight: 50, reps: 10, completedSets: sets)
        #expect(low == 6.0)

        // Very heavy weight
        let high = estimator.estimateRPE(weight: 140, reps: 1, completedSets: sets)
        #expect(high == 10.0)
    }

    @Test("result snaps to 0.5 increments")
    func resultSnapsToHalf() {
        let sets = [makeSet(weight: 100, reps: 10)]
        let result = estimator.estimateRPE(weight: 100, reps: 8, completedSets: sets)
        #expect(result != nil)
        let remainder = result!.truncatingRemainder(dividingBy: 0.5)
        #expect(remainder == 0.0)
    }

    @Test("single rep set returns weight as 1RM")
    func singleRepSet() {
        // Set 1: 120kg × 1 → 1RM = 120
        // Set 2: 120kg × 1 → %1RM = 1.0 → RPE 10
        let sets = [makeSet(weight: 120, reps: 1)]
        let result = estimator.estimateRPE(weight: 120, reps: 1, completedSets: sets)
        #expect(result == 10.0)
    }

    // MARK: - Helpers

    private func makeSet(weight: Double, reps: Int, setNumber: Int = 1) -> CompletedSetData {
        CompletedSetData(setNumber: setNumber, weight: weight, reps: reps, completedAt: Date())
    }
}
