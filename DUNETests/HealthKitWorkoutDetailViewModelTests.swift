import Foundation
import Testing
@testable import DUNE

@Suite("HealthKitWorkoutDetailViewModel")
@MainActor
struct HealthKitWorkoutDetailViewModelTests {

    @Test("heartRateAverage prefers workout summary value")
    func heartRateAveragePrefersWorkoutValue() {
        let viewModel = HealthKitWorkoutDetailViewModel()
        viewModel.heartRateSummary = HeartRateSummary(
            average: 140,
            max: 165,
            min: 100,
            samples: []
        )
        let workout = WorkoutSummary(
            id: "w1",
            type: "Running",
            activityType: .running,
            duration: 1200,
            calories: 200,
            distance: 3000,
            date: Date(),
            heartRateAvg: 128
        )

        let value = viewModel.heartRateAverage(for: workout)

        #expect(value == 128)
    }

    @Test("heartRateAverage falls back to loaded heart-rate summary")
    func heartRateAverageFallsBackToSummary() {
        let viewModel = HealthKitWorkoutDetailViewModel()
        viewModel.heartRateSummary = HeartRateSummary(
            average: 133,
            max: 170,
            min: 90,
            samples: [
                HeartRateSample(bpm: 120, date: Date()),
                HeartRateSample(bpm: 146, date: Date())
            ]
        )
        let workout = WorkoutSummary(
            id: "w2",
            type: "Running",
            activityType: .running,
            duration: 1000,
            calories: 180,
            distance: 2500,
            date: Date(),
            heartRateAvg: nil
        )

        let value = viewModel.heartRateAverage(for: workout)

        #expect(value == 133)
    }

    @Test("heartRateAverage returns nil when workout and summary are unavailable")
    func heartRateAverageReturnsNilWithoutData() {
        let viewModel = HealthKitWorkoutDetailViewModel()
        viewModel.heartRateSummary = nil
        let workout = WorkoutSummary(
            id: "w3",
            type: "Running",
            activityType: .running,
            duration: 1000,
            calories: 150,
            distance: 2000,
            date: Date(),
            heartRateAvg: nil
        )

        let value = viewModel.heartRateAverage(for: workout)

        #expect(value == nil)
    }

    @Test("heartRateMax prefers workout summary value")
    func heartRateMaxPrefersWorkoutValue() {
        let viewModel = HealthKitWorkoutDetailViewModel()
        viewModel.heartRateSummary = HeartRateSummary(
            average: 130,
            max: 172,
            min: 96,
            samples: []
        )
        let workout = WorkoutSummary(
            id: "w4",
            type: "Running",
            activityType: .running,
            duration: 800,
            calories: 120,
            distance: 1800,
            date: Date(),
            heartRateMax: 165
        )

        let value = viewModel.heartRateMax(for: workout)

        #expect(value == 165)
    }

    @Test("heartRateMax falls back to loaded heart-rate summary")
    func heartRateMaxFallsBackToSummary() {
        let viewModel = HealthKitWorkoutDetailViewModel()
        viewModel.heartRateSummary = HeartRateSummary(
            average: 129,
            max: 169,
            min: 90,
            samples: [
                HeartRateSample(bpm: 120, date: Date()),
                HeartRateSample(bpm: 160, date: Date())
            ]
        )
        let workout = WorkoutSummary(
            id: "w5",
            type: "Running",
            activityType: .running,
            duration: 800,
            calories: 120,
            distance: 1800,
            date: Date(),
            heartRateMax: nil
        )

        let value = viewModel.heartRateMax(for: workout)

        #expect(value == 169)
    }

    @Test("stepCount for workout range prefers WorkoutSummary value")
    func stepCountPrefersWorkoutSummary() {
        let viewModel = HealthKitWorkoutDetailViewModel()
        viewModel.workoutStepCount = 900

        let workout = WorkoutSummary(
            id: "walk-1",
            type: "Walking",
            activityType: .walking,
            duration: 1800,
            calories: 160,
            distance: 2000,
            date: Date(),
            stepCount: 1_234
        )

        let value = viewModel.stepCount(for: workout, range: .workout)

        #expect(value == 1_234)
    }

    @Test("stepCount returns day and week cached values by range")
    func stepCountRespectsSelectedRange() {
        let viewModel = HealthKitWorkoutDetailViewModel()
        viewModel.workoutStepCount = 1_000
        viewModel.dayStepCount = 5_500
        viewModel.weekStepCount = 24_000

        let workout = WorkoutSummary(
            id: "walk-2",
            type: "Walking",
            activityType: .walking,
            duration: 2100,
            calories: 170,
            distance: 2200,
            date: Date(),
            stepCount: nil
        )

        #expect(viewModel.stepCount(for: workout, range: .workout) == 1_000)
        #expect(viewModel.stepCount(for: workout, range: .day) == 5_500)
        #expect(viewModel.stepCount(for: workout, range: .week) == 24_000)
    }
}
