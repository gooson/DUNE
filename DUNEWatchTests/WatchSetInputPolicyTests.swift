import Testing
@testable import DUNEWatch

@Suite("WatchSetInputPolicy")
struct WatchSetInputPolicyTests {
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
    }
}
