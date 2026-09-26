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
}
