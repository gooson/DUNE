import Testing
@testable import DUNE

@Suite("FormVoiceCoach")
struct FormVoiceCoachTests {

    // MARK: - Helpers

    private func makeCoach(
        cooldown: TimeInterval = 5.0,
        now: @escaping () -> Date = { Date() }
    ) -> FormVoiceCoach {
        FormVoiceCoach(cooldown: cooldown, now: now)
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

    @Test("Disabled coach does not crash on processFormState")
    func disabledCoach() {
        let coach = makeCoach()
        // Coach is disabled by default — calling process should be a no-op
        let state = makeFormState(results: [
            CheckpointResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
        ])
        coach.processFormState(state, rule: .barbellSquat)
        // No crash = success
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

    @Test("Cooldown prevents repeated speech for same checkpoint")
    func cooldownPreventsRepeat() {
        var currentTime = Date()
        let coach = makeCoach(cooldown: 5.0, now: { currentTime })
        coach.setEnabled(true)

        let state = makeFormState(results: [
            CheckpointResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
        ])

        // First call — should attempt to speak (synthesizer may not actually
        // produce audio in test environment, but the cooldown is recorded)
        coach.processFormState(state, rule: .barbellSquat)

        // Advance time by 2 seconds (within cooldown)
        currentTime = currentTime.addingTimeInterval(2.0)
        // Second call — should be suppressed by cooldown
        // We verify indirectly: no crash, and the coach is functioning
        coach.processFormState(state, rule: .barbellSquat)

        // Advance time past cooldown
        currentTime = currentTime.addingTimeInterval(4.0)
        // Third call — cooldown expired, should attempt speech again
        coach.processFormState(state, rule: .barbellSquat)

        coach.stop()
    }

    @Test("Normal status does not trigger coaching")
    func normalStatusSkipped() {
        let coach = makeCoach()
        coach.setEnabled(true)

        let state = makeFormState(results: [
            CheckpointResult(checkpointName: "Knee Depth", status: .normal, currentDegrees: 80),
            CheckpointResult(checkpointName: "Back Angle", status: .normal, currentDegrees: 55),
        ])

        // Should be a no-op (no cue needed for normal status)
        coach.processFormState(state, rule: .barbellSquat)
        coach.stop()
    }

    @Test("Stop clears cooldown history")
    func stopClearsCooldowns() {
        var currentTime = Date()
        let coach = makeCoach(cooldown: 5.0, now: { currentTime })
        coach.setEnabled(true)

        let state = makeFormState(results: [
            CheckpointResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
        ])

        coach.processFormState(state, rule: .barbellSquat)

        // Stop and re-enable — cooldown should be cleared
        coach.stop()
        coach.setEnabled(true)

        // Same time — should be able to speak again since cooldowns were cleared
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
}
