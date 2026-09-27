import Foundation
import Testing
@testable import DUNEWatch

@Suite("WatchSetInputPolicy")
struct WatchSetInputPolicyTests {
    @Test("Removing added weight does not restore the template default")
    func removedWeightStaysRemoved() {
        #expect(WatchSetInputPolicy.resolvedWeight(previousWeight: nil, defaultWeight: 20, hasPreviousSet: true) == 0)
        #expect(WatchSetInputPolicy.resolvedWeight(previousWeight: nil, defaultWeight: 20, hasPreviousSet: false) == 20)
    }

    @Test("Invalid weights cannot enter a session", arguments: [Double.nan, .infinity, -1, 501])
    func invalidWeights(value: Double) {
        #expect(WatchSetInputPolicy.resolvedWeight(previousWeight: value, defaultWeight: 20, hasPreviousSet: true) == 0)
        #expect(WatchSetInputPolicy.completedWeight(value, inputType: .setsReps) == nil)
    }

    @Test("Only strength and optionally weighted bodyweight sets store load")
    func weightCapability() {
        #expect(WatchSetInputPolicy.completedWeight(5, inputType: .setsReps) == 5)
        #expect(WatchSetInputPolicy.completedWeight(5, inputType: .setsRepsWeight) == 5)
        #expect(WatchSetInputPolicy.completedWeight(0, inputType: .setsReps) == nil)
        for type in [ExerciseInputType.durationDistance, .durationIntensity, .roundsBased] {
            #expect(WatchSetInputPolicy.completedWeight(5, inputType: type) == nil)
        }
    }
    @Test("resolvedInitialReps prefers last set reps when valid")
    func resolvedInitialRepsPrefersLastSet() {
        let resolved = WatchSetInputPolicy.resolvedInitialReps(lastSetReps: 6, entryDefaultReps: 10)
        #expect(resolved == 6)
    }

    @Test("resolvedInitialReps falls back to entry default when last set reps are missing")
    func resolvedInitialRepsFallsBackToEntryDefault() {
        let resolved = WatchSetInputPolicy.resolvedInitialReps(lastSetReps: nil, entryDefaultReps: 12)
        #expect(resolved == 12)
    }

    @Test("resolvedInitialReps uses global default 10 when both values are invalid")
    func resolvedInitialRepsUsesGlobalDefault() {
        let resolved = WatchSetInputPolicy.resolvedInitialReps(lastSetReps: 0, entryDefaultReps: 0)
        #expect(resolved == WatchSetInputPolicy.defaultReps)
        #expect(resolved == 10)
    }

    @Test("isValidForCompletion rejects zero reps")
    func isValidForCompletionRejectsZero() {
        #expect(!WatchSetInputPolicy.isValidForCompletion(reps: 0))
    }

    @Test("isValidForCompletion allows positive reps in supported range")
    func isValidForCompletionAllowsPositiveRange() {
        #expect(WatchSetInputPolicy.isValidForCompletion(reps: 1))
        #expect(WatchSetInputPolicy.isValidForCompletion(reps: 1000))
        #expect(WatchSetInputPolicy.maximumEditableReps == WatchSetInputPolicy.maximumCompletionReps)
    }

    @Test("Missed target offers a lighter next working set")
    func missedTargetOffersReduction() {
        let set = completedSet(reps: 7, plannedReps: 8, rpe: nil, source: nil)
        let result = WatchSetInputPolicy.reducedWeight(
            after: set, nextSetTypeRaw: SetType.working.rawValue,
            equipmentRaw: Equipment.barbell.rawValue, inputType: .setsRepsWeight
        )
        #expect(result == 37.5)
    }

    @Test("Only confirmed high RPE offers a lighter next set")
    func highRPERequiresUserSource() {
        let estimated = completedSet(reps: 8, plannedReps: 8, rpe: 9, source: "estimated")
        let confirmed = completedSet(reps: 8, plannedReps: 8, rpe: 9, source: "user")
        #expect(WatchSetInputPolicy.reducedWeight(
            after: estimated, nextSetTypeRaw: nil,
            equipmentRaw: Equipment.barbell.rawValue, inputType: .setsRepsWeight
        ) == nil)
        #expect(WatchSetInputPolicy.reducedWeight(
            after: confirmed, nextSetTypeRaw: nil,
            equipmentRaw: Equipment.barbell.rawValue, inputType: .setsRepsWeight
        ) == 37.5)
    }

    @Test("Warmup and non-weighted work never offer a weight reduction")
    func ignoresIneligibleSets() {
        let working = completedSet(reps: 7, plannedReps: 8, rpe: nil, source: nil)
        var warmup = working
        warmup.setTypeRaw = SetType.warmup.rawValue
        #expect(WatchSetInputPolicy.reducedWeight(
            after: warmup, nextSetTypeRaw: nil,
            equipmentRaw: Equipment.barbell.rawValue, inputType: .setsRepsWeight
        ) == nil)
        #expect(WatchSetInputPolicy.reducedWeight(
            after: working, nextSetTypeRaw: SetType.warmup.rawValue,
            equipmentRaw: Equipment.barbell.rawValue, inputType: .setsRepsWeight
        ) == nil)
        #expect(WatchSetInputPolicy.reducedWeight(
            after: working, nextSetTypeRaw: nil,
            equipmentRaw: Equipment.barbell.rawValue, inputType: .roundsBased
        ) == nil)
    }

    @Test("Synced progression increment takes precedence over equipment fallback")
    func syncedIncrementTakesPrecedence() {
        let set = completedSet(reps: 7, plannedReps: 8, rpe: nil, source: nil)
        let fallback = WatchSetInputPolicy.reducedWeight(
            after: set, nextSetTypeRaw: nil,
            equipmentRaw: Equipment.band.rawValue, inputType: .setsRepsWeight
        )
        let synced = WatchSetInputPolicy.reducedWeight(
            after: set, nextSetTypeRaw: nil,
            equipmentRaw: Equipment.band.rawValue, progressionIncrementKg: 5,
            inputType: .setsRepsWeight
        )
        #expect(fallback == 36)
        #expect(synced == 37.5)
    }

    private func completedSet(reps: Int, plannedReps: Int, rpe: Double?, source: String?) -> CompletedSetData {
        CompletedSetData(
            setNumber: 1, weight: 40, reps: reps, duration: nil, completedAt: Date(),
            rpe: rpe, plannedReps: plannedReps, rpeSourceRaw: source,
            setTypeRaw: SetType.working.rawValue
        )
    }
}
