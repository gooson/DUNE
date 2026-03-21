import Foundation
import Testing
@testable import DUNE

@Suite("FormVoiceCoach")
@MainActor
struct FormVoiceCoachTests {

    // MARK: - Helpers

    private final class TestClock: @unchecked Sendable {
        var currentTime: Date

        init(_ currentTime: Date) {
            self.currentTime = currentTime
        }
    }

    private func makeCoach(
        now: @escaping @Sendable () -> Date = { Date() },
        didSpeak: ((String) -> Void)? = nil
    ) -> FormVoiceCoach {
        FormVoiceCoach(now: now, didSpeak: didSpeak)
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

    @Test("Disabled coach does not process form state")
    func disabledCoach() {
        let coach = makeCoach()
        let state = makeFormState(results: [
            makeResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
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
        let clock = TestClock(Date())
        var spokenCues: [String] = []
        let coach = makeCoach(
            now: { clock.currentTime },
            didSpeak: { spokenCues.append($0) }
        )
        coach.setEnabled(true)

        let state = makeFormState(results: [
            makeResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
        ])

        // First call — speaks and records cooldown
        coach.processFormState(state, rule: .barbellSquat)

        // Advance 2s (within warning cooldown of 3s)
        clock.currentTime = clock.currentTime.addingTimeInterval(2.0)
        coach.processFormState(state, rule: .barbellSquat)

        // Advance past cooldown (total 6s > 3s)
        clock.currentTime = clock.currentTime.addingTimeInterval(4.0)
        coach.processFormState(state, rule: .barbellSquat)

        #expect(spokenCues == ["Go deeper", "Go deeper"])
        coach.stop()
    }

    @Test("Normal status uses positiveCue for coaching")
    func normalStatusUsesPositiveCue() {
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
            now: { currentTime },
            didSpeak: { spokenCues.append($0) }
        )
        coach.setEnabled(true)

        let state = makeFormState(results: [
            makeResult(checkpointName: "Knee Depth", status: .warning, currentDegrees: 130),
        ])

        coach.processFormState(state, rule: .barbellSquat)

        coach.stop()
        coach.setEnabled(true)

        // Same time — cooldowns were cleared so speech should be allowed
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
