import Foundation
import Testing
@testable import DUNEWatch

@Suite("CardioInactivityActivitySignal")
struct CardioInactivitySignalTests {
    private func metrics(
        distance: Double = 0,
        steps: Double = 0,
        floorsClimbed: Double = 0,
        activeCalories: Double = 0
    ) -> CardioInactivityObservedMetrics {
        CardioInactivityObservedMetrics(
            distance: distance,
            steps: steps,
            floorsClimbed: floorsClimbed,
            activeCalories: activeCalories
        )
    }

    @Test("Distance progress still counts for standard cardio")
    func distanceProgressCounts() {
        let previous = metrics(distance: 500, steps: 700, activeCalories: 45)
        let current = metrics(distance: 650, steps: 700, activeCalories: 46)

        let progressed = CardioInactivityActivitySignal.hasProgress(
            workoutMode: .cardio(activityType: .running, isOutdoor: true),
            supportsMachineLevel: false,
            previous: previous,
            current: current
        )

        #expect(progressed)
    }

    @Test("Stair cardio counts floors climbed as progress")
    func stairFloorsCount() {
        let previous = metrics(steps: 0, floorsClimbed: 12, activeCalories: 80)
        let current = metrics(steps: 0, floorsClimbed: 13, activeCalories: 80)

        let progressed = CardioInactivityActivitySignal.hasProgress(
            workoutMode: .cardio(activityType: .stairClimbing, isOutdoor: false),
            supportsMachineLevel: true,
            previous: previous,
            current: current
        )

        #expect(progressed)
    }

    @Test("Machine cardio counts calorie growth as fallback progress")
    func machineCaloriesCount() {
        let previous = metrics(distance: 0, steps: 0, floorsClimbed: 0, activeCalories: 120)
        let current = metrics(distance: 0, steps: 0, floorsClimbed: 0, activeCalories: 123)

        let progressed = CardioInactivityActivitySignal.hasProgress(
            workoutMode: .cardio(activityType: .elliptical, isOutdoor: false),
            supportsMachineLevel: true,
            previous: previous,
            current: current
        )

        #expect(progressed)
    }

    @Test("Calories alone do not count for standard distance cardio")
    func caloriesDoNotBroadenDistanceCardio() {
        let previous = metrics(distance: 1_000, steps: 1_400, activeCalories: 90)
        let current = metrics(distance: 1_000, steps: 1_400, activeCalories: 94)

        let progressed = CardioInactivityActivitySignal.hasProgress(
            workoutMode: .cardio(activityType: .running, isOutdoor: true),
            supportsMachineLevel: false,
            previous: previous,
            current: current
        )

        #expect(!progressed)
    }

    @Test("Static machine cardio metrics do not count as progress")
    func staticMachineMetricsDoNotCount() {
        let previous = metrics(distance: 0, steps: 0, floorsClimbed: 5, activeCalories: 70)
        let current = metrics(distance: 0, steps: 0, floorsClimbed: 5, activeCalories: 70)

        let progressed = CardioInactivityActivitySignal.hasProgress(
            workoutMode: .cardio(activityType: .stairStepper, isOutdoor: false),
            supportsMachineLevel: true,
            previous: previous,
            current: current
        )

        #expect(!progressed)
    }
}
