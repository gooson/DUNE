import Foundation
import Testing
@testable import DUNE

@Suite("FormVoiceCoach")
struct FormVoiceCoachTests {

    // MARK: - Helpers

    private func makeCoach(
        cooldown: TimeInterval = 5.0,
        now: @escaping () -> Date = { Date() },
        didSpeak: ((String) -> Void)? = nil
    ) -> FormVoiceCoach {
        FormVoiceCoach(cooldown: cooldown, now: now, didSpeak: didSpeak)
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

    private func makeResult(
        checkpointName: String,
        status: PostureStatus,
        currentDegrees: Double,
        isActivePhase: Bool = true
    ) -> CheckpointResult {
        CheckpointResult(
            checkpointName: checkpointName,
            isActivePhase: isActivePhase,
            status: status,
            currentDegrees: currentDegrees
        )
    }

    // MARK: - Tests

    @Test("Disabled coach does not crash on processFormState")
    func disabledCoach() {
        let coach = makeCoach()
        // Coach is disabled by default — calling process should be a no-op
        let state = makeFormState(results: [
            makeResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
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
        var spokenCues: [String] = []
        let coach = makeCoach(
            cooldown: 5.0,
            now: { currentTime },
            didSpeak: { spokenCues.append($0) }
        )
        coach.setEnabled(true)

        let state = makeFormState(results: [
            makeResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
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

        #expect(spokenCues == ["Go deeper", "Go deeper"])
        coach.stop()
    }

    @Test("Active normal status can emit a positive coaching cue")
    func normalStatusCanTriggerPositiveCue() {
        var spokenCues: [String] = []
        let coach = makeCoach(didSpeak: { spokenCues.append($0) })
        coach.setEnabled(true)

        let state = makeFormState(results: [
            makeResult(checkpointName: "Knee Depth", status: .normal, currentDegrees: 80),
            makeResult(checkpointName: "Back Angle", status: .normal, currentDegrees: 55),
        ])

        coach.processFormState(state, rule: .barbellSquat)

        #expect(spokenCues == ["Good depth"])
        coach.stop()
    }

    @Test("Inactive checkpoints are ignored even if they look normal")
    func inactiveCheckpointsAreIgnored() {
        var spokenCues: [String] = []
        let coach = makeCoach(didSpeak: { spokenCues.append($0) })
        coach.setEnabled(true)

        let state = makeFormState(
            results: [
                makeResult(
                    checkpointName: "Knee Depth",
                    status: .normal,
                    currentDegrees: 170,
                    isActivePhase: false
                ),
                makeResult(
                    checkpointName: "Back Angle",
                    status: .normal,
                    currentDegrees: 55,
                    isActivePhase: false
                ),
            ],
            phase: .setup
        )

        coach.processFormState(state, rule: .barbellSquat)

        #expect(spokenCues.isEmpty)
        coach.stop()
    }

    @Test("Stop clears cooldown history")
    func stopClearsCooldowns() {
        let currentTime = Date()
        var spokenCues: [String] = []
        let coach = makeCoach(
            cooldown: 5.0,
            now: { currentTime },
            didSpeak: { spokenCues.append($0) }
        )
        coach.setEnabled(true)

        let state = makeFormState(results: [
            makeResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
        ])

        coach.processFormState(state, rule: .barbellSquat)

        // Stop and re-enable — cooldown should be cleared
        coach.stop()
        coach.setEnabled(true)

        // Same time — should be able to speak again since cooldowns were cleared
        coach.processFormState(state, rule: .barbellSquat)

        #expect(spokenCues == ["Go deeper", "Go deeper"])
        coach.stop()
    }

    @Test("Unmeasurable status does not trigger coaching")
    func unmeasurableSkipped() {
        let coach = makeCoach()
        coach.setEnabled(true)

        let state = makeFormState(results: [
            makeResult(checkpointName: "Knee Depth", status: .unmeasurable, currentDegrees: 0),
        ])

        coach.processFormState(state, rule: .barbellSquat)
        coach.stop()
    }
}
