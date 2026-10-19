import Foundation
import Testing
@testable import DUNEWatch

@Suite("CardioInactivityPolicy")
struct CardioInactivityPolicyTests {
    @Test("Returns none before soft threshold")
    func evaluateReturnsNoneBeforeSoftThreshold() {
        let now = Date()

        let result = CardioInactivityPolicy.evaluate(
            workoutMode: .cardio(activityType: .running, isOutdoor: true),
            inactivityDuration: CardioInactivityPolicy.softNudgeAfter - 1,
            autoEndDeadline: nil,
            now: now
        )

        #expect(result == .none)
    }

    @Test("Returns softNudge between thresholds")
    func evaluateReturnsSoftNudgeBetweenThresholds() {
        let now = Date()

        let result = CardioInactivityPolicy.evaluate(
            workoutMode: .cardio(activityType: .running, isOutdoor: true),
            inactivityDuration: CardioInactivityPolicy.softNudgeAfter,
            autoEndDeadline: nil,
            now: now
        )

        #expect(result == .softNudge)
    }

    @Test("Returns confirmation at confirmation threshold")
    func evaluateReturnsConfirmationAtConfirmationThreshold() {
        let now = Date()

        let result = CardioInactivityPolicy.evaluate(
            workoutMode: .cardio(activityType: .running, isOutdoor: true),
            inactivityDuration: CardioInactivityPolicy.confirmationAfter,
            autoEndDeadline: nil,
            now: now
        )

        guard case .confirmation(let deadline) = result else {
            Issue.record("Expected confirmation state")
            return
        }

        #expect(
            abs(deadline.timeIntervalSince(now) - CardioInactivityPolicy.countdownDuration) < 0.001
        )
    }

    @Test("Respects existing deadline until autoEnd")
    func evaluateRespectsExistingDeadlineUntilAutoEnd() {
        let now = Date()
        let futureDeadline = now.addingTimeInterval(4)

        let beforeDeadline = CardioInactivityPolicy.evaluate(
            workoutMode: .cardio(activityType: .running, isOutdoor: true),
            inactivityDuration: 999,
            autoEndDeadline: futureDeadline,
            now: now
        )
        #expect(beforeDeadline == .confirmation(deadline: futureDeadline))

        let afterDeadline = CardioInactivityPolicy.evaluate(
            workoutMode: .cardio(activityType: .running, isOutdoor: true),
            inactivityDuration: 999,
            autoEndDeadline: futureDeadline,
            now: futureDeadline
        )
        #expect(afterDeadline == .autoEnd)
    }

    @Test("Stair workout stays active through the former exit suggestion window")
    func stairWorkoutContinuesThroughWalkingLikeMetrics() {
        let start = Date(timeIntervalSince1970: 1_000)
        let mode = WorkoutMode.cardio(activityType: .stairClimbing, isOutdoor: false)
        let samples: [(seconds: TimeInterval, distance: Double, steps: Double)] = [
            (90, 0, 120), (100, 7, 125), (119, 29, 141), (120, 32, 142)
        ]

        var previous = CardioInactivityObservedMetrics(
            distance: 0, steps: 0, floorsClimbed: 0, activeCalories: 0
        )
        for sample in samples {
            let current = CardioInactivityObservedMetrics(
                distance: sample.distance, steps: sample.steps,
                floorsClimbed: 0, activeCalories: 0
            )
            #expect(CardioInactivityActivitySignal.hasProgress(
                workoutMode: mode, supportsMachineLevel: true,
                previous: previous, current: current
            ))
            previous = current
            let now = start.addingTimeInterval(sample.seconds)
            let result = CardioInactivityPolicy.evaluate(
                workoutMode: mode,
                inactivityDuration: sample.seconds,
                autoEndDeadline: nil,
                now: now
            )
            let elapsed = WorkoutElapsedTime.activeElapsedTime(
                startDate: start, pausedDuration: 0, pauseStart: nil,
                isPaused: false, now: now
            )

            #expect(result == .none)
            #expect(elapsed == sample.seconds)
        }
    }

    @Test("Stair machine workouts do not prompt or auto-end from missing wrist motion")
    func stairMachineIgnoresMissingMotion() {
        let now = Date()

        for activityType in [WorkoutActivityType.stairClimbing, .stairStepper] {
            let workoutMode = WorkoutMode.cardio(activityType: activityType, isOutdoor: false)

            #expect(CardioInactivityPolicy.evaluate(
                workoutMode: workoutMode,
                inactivityDuration: CardioInactivityPolicy.softNudgeAfter,
                autoEndDeadline: nil,
                now: now
            ) == .none)
            #expect(CardioInactivityPolicy.evaluate(
                workoutMode: workoutMode,
                inactivityDuration: CardioInactivityPolicy.confirmationAfter,
                autoEndDeadline: nil,
                now: now
            ) == .none)
            #expect(CardioInactivityPolicy.evaluate(
                workoutMode: workoutMode,
                inactivityDuration: CardioInactivityPolicy.confirmationAfter + 30,
                autoEndDeadline: now.addingTimeInterval(-1),
                now: now
            ) == .none)
        }
    }
}
