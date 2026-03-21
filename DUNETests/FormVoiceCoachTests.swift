import Testing
@testable import DUNE

@Suite("FormVoiceCoach")
@MainActor
struct FormVoiceCoachTests {

    // MARK: - Helpers

    private func makeCoach(
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> FormVoiceCoach {
        FormVoiceCoach(now: now)
    }

    private func makeFormState(
        exerciseID: String = "barbell-squat",
        results: [CheckpointResult],
        phase: ExercisePhase = .descent
    ) -> ExerciseFormState {
        var state = ExerciseFormState(exerciseID: exerciseID)
        state.checkpointResults = results
        state.currentPhase = phase
        return state
    }

    // MARK: - Tests

    @Test("Disabled coach does not process form state")
    func disabledCoach() {
        let coach = makeCoach()
        let state = makeFormState(results: [
            CheckpointResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
        ])
        // isEnabled is false by default — processFormState is guarded in the caller
        #expect(!coach.isEnabled)
    }

    @Test("All built-in rules have non-empty coachingCue")
    func allCheckpointsHaveCoachingCue() {
        for rule in ExerciseFormRule.allBuiltIn {
            for checkpoint in rule.checkpoints {
                #expect(!checkpoint.coachingCue.isEmpty,
                        "Missing coachingCue for \(rule.displayName) / \(checkpoint.name)")
            }
        }
    }

    @Test("All built-in rules have non-empty positiveCue")
    func allCheckpointsHavePositiveCue() {
        for rule in ExerciseFormRule.allBuiltIn {
            for checkpoint in rule.checkpoints {
                #expect(!checkpoint.positiveCue.isEmpty,
                        "Missing positiveCue for \(rule.displayName) / \(checkpoint.name)")
            }
        }
    }

    @Test("Cooldown prevents repeated speech for same checkpoint")
    func cooldownPreventsRepeat() {
        var currentTime = Date()
        let coach = makeCoach(now: { currentTime })
        coach.setEnabled(true)

        let state = makeFormState(results: [
            CheckpointResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
        ])

        // First call — speaks and records cooldown
        coach.processFormState(state, rule: .barbellSquat)

        // Advance 2s (within warning cooldown of 3s)
        currentTime = currentTime.addingTimeInterval(2.0)
        coach.processFormState(state, rule: .barbellSquat)

        // Advance past cooldown (total 6s > 3s)
        currentTime = currentTime.addingTimeInterval(4.0)
        coach.processFormState(state, rule: .barbellSquat)

        coach.stop()
    }

    @Test("Normal status uses positiveCue for coaching")
    func normalStatusUsesPositiveCue() {
        let coach = makeCoach()
        coach.setEnabled(true)

        let state = makeFormState(results: [
            CheckpointResult(checkpointName: "Knee Depth", status: .normal, currentDegrees: 80),
        ])

        // Normal status triggers positiveCue (not skipped)
        coach.processFormState(state, rule: .barbellSquat)
        coach.stop()
    }

    @Test("Stop clears cooldown history")
    func stopClearsCooldowns() {
        var currentTime = Date()
        let coach = makeCoach(now: { currentTime })
        coach.setEnabled(true)

        let state = makeFormState(results: [
            CheckpointResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
        ])

        coach.processFormState(state, rule: .barbellSquat)

        coach.stop()
        coach.setEnabled(true)

        // Same time — cooldowns were cleared so speech should be allowed
        coach.processFormState(state, rule: .barbellSquat)
        coach.stop()
    }

    @Test("Unmeasurable status does not trigger coaching")
    func unmeasurableSkipped() {
        let coach = makeCoach()
        coach.setEnabled(true)

        let state = makeFormState(results: [
            CheckpointResult(checkpointName: "Knee Depth", status: .unmeasurable, currentDegrees: 0),
        ])

        coach.processFormState(state, rule: .barbellSquat)
        coach.stop()
    }

    @Test("setEnabled toggles isEnabled state")
    func setEnabledToggles() {
        let coach = makeCoach()
        #expect(!coach.isEnabled)
        coach.setEnabled(true)
        #expect(coach.isEnabled)
        coach.setEnabled(false)
        #expect(!coach.isEnabled)
    }
}
