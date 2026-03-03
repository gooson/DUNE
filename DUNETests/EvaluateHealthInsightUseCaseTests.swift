import Foundation
import Testing
@testable import DUNE

@Suite("EvaluateHealthInsightUseCase")
struct EvaluateHealthInsightUseCaseTests {

    // MARK: - HRV Anomaly

    @Test("HRV: returns nil when baseline too short")
    func hrvBaselineTooShort() {
        let result = EvaluateHealthInsightUseCase.evaluateHRV(
            todayValue: 50,
            recentDailyAverages: [40, 42, 38, 41, 39, 43] // 6 entries, need 7
        )
        #expect(result == nil)
    }

    @Test("HRV: returns nil when within normal range")
    func hrvWithinNormalRange() {
        let baseline = Array(repeating: 50.0, count: 7)
        let result = EvaluateHealthInsightUseCase.evaluateHRV(
            todayValue: 52, // 4% higher — below 20% threshold
            recentDailyAverages: baseline
        )
        #expect(result == nil)
    }

    @Test("HRV: detects significant increase")
    func hrvSignificantIncrease() {
        let baseline = Array(repeating: 50.0, count: 7)
        let result = EvaluateHealthInsightUseCase.evaluateHRV(
            todayValue: 65, // 30% higher
            recentDailyAverages: baseline
        )
        #expect(result != nil)
        #expect(result?.type == .hrvAnomaly)
        #expect(result?.severity == .attention)
    }

    @Test("HRV: detects significant decrease")
    func hrvSignificantDecrease() {
        let baseline = Array(repeating: 50.0, count: 7)
        let result = EvaluateHealthInsightUseCase.evaluateHRV(
            todayValue: 35, // 30% lower
            recentDailyAverages: baseline
        )
        #expect(result != nil)
        #expect(result?.type == .hrvAnomaly)
    }

    @Test("HRV: returns nil for zero value")
    func hrvZeroValue() {
        let baseline = Array(repeating: 50.0, count: 7)
        let result = EvaluateHealthInsightUseCase.evaluateHRV(
            todayValue: 0,
            recentDailyAverages: baseline
        )
        #expect(result == nil)
    }

    @Test("HRV: returns nil for NaN value")
    func hrvNaN() {
        let baseline = Array(repeating: 50.0, count: 7)
        let result = EvaluateHealthInsightUseCase.evaluateHRV(
            todayValue: .nan,
            recentDailyAverages: baseline
        )
        #expect(result == nil)
    }

    // MARK: - RHR Anomaly

    @Test("RHR: detects significant increase")
    func rhrSignificantIncrease() {
        let baseline = Array(repeating: 60.0, count: 7)
        let result = EvaluateHealthInsightUseCase.evaluateRHR(
            todayValue: 72, // 20% higher, above 15% threshold
            recentDailyAverages: baseline
        )
        #expect(result != nil)
        #expect(result?.type == .rhrAnomaly)
        #expect(result?.severity == .attention)
    }

    @Test("RHR: returns nil when within normal range")
    func rhrWithinNormalRange() {
        let baseline = Array(repeating: 60.0, count: 7)
        let result = EvaluateHealthInsightUseCase.evaluateRHR(
            todayValue: 63, // 5% higher — below 15% threshold
            recentDailyAverages: baseline
        )
        #expect(result == nil)
    }

    @Test("RHR: returns nil for baseline too short")
    func rhrBaselineTooShort() {
        let result = EvaluateHealthInsightUseCase.evaluateRHR(
            todayValue: 72,
            recentDailyAverages: [60, 62, 58]
        )
        #expect(result == nil)
    }

    // MARK: - Sleep Complete

    @Test("Sleep: creates insight for valid sleep")
    func sleepValid() {
        let result = EvaluateHealthInsightUseCase.evaluateSleepComplete(totalMinutes: 480)
        #expect(result != nil)
        #expect(result?.type == .sleepComplete)
        #expect(result?.severity == .informational)
    }

    @Test("Sleep: returns nil for zero minutes")
    func sleepZero() {
        let result = EvaluateHealthInsightUseCase.evaluateSleepComplete(totalMinutes: 0)
        #expect(result == nil)
    }

    @Test("Sleep: returns nil for negative minutes")
    func sleepNegative() {
        let result = EvaluateHealthInsightUseCase.evaluateSleepComplete(totalMinutes: -30)
        #expect(result == nil)
    }

    // MARK: - Step Goal

    @Test("Steps: triggers at goal threshold")
    func stepsAtGoal() {
        let result = EvaluateHealthInsightUseCase.evaluateStepGoal(todaySteps: 10_000)
        #expect(result != nil)
        #expect(result?.type == .stepGoal)
        #expect(result?.severity == .celebration)
    }

    @Test("Steps: triggers above goal")
    func stepsAboveGoal() {
        let result = EvaluateHealthInsightUseCase.evaluateStepGoal(todaySteps: 15_000)
        #expect(result != nil)
    }

    @Test("Steps: returns nil below goal")
    func stepsBelowGoal() {
        let result = EvaluateHealthInsightUseCase.evaluateStepGoal(todaySteps: 9_999)
        #expect(result == nil)
    }

    // MARK: - Weight Update

    @Test("Weight: creates insight with delta")
    func weightWithDelta() {
        let result = EvaluateHealthInsightUseCase.evaluateWeight(
            newValue: 75.0,
            previousValue: 76.0
        )
        #expect(result != nil)
        #expect(result?.type == .weightUpdate)
        #expect(result?.severity == .informational)
    }

    @Test("Weight: creates insight without previous value")
    func weightNoPrevious() {
        let result = EvaluateHealthInsightUseCase.evaluateWeight(
            newValue: 75.0,
            previousValue: nil
        )
        #expect(result != nil)
    }

    @Test("Weight: returns nil for out-of-range value")
    func weightOutOfRange() {
        let result = EvaluateHealthInsightUseCase.evaluateWeight(
            newValue: 600,
            previousValue: nil
        )
        #expect(result == nil)
    }

    @Test("Weight: returns nil for zero")
    func weightZero() {
        let result = EvaluateHealthInsightUseCase.evaluateWeight(
            newValue: 0,
            previousValue: nil
        )
        #expect(result == nil)
    }

    // MARK: - Body Fat Update

    @Test("BodyFat: creates insight for valid value")
    func bodyFatValid() {
        let result = EvaluateHealthInsightUseCase.evaluateBodyFat(newValue: 18.5)
        #expect(result != nil)
        #expect(result?.type == .bodyFatUpdate)
    }

    @Test("BodyFat: returns nil for zero")
    func bodyFatZero() {
        let result = EvaluateHealthInsightUseCase.evaluateBodyFat(newValue: 0)
        #expect(result == nil)
    }

    @Test("BodyFat: returns nil for over 100")
    func bodyFatOver100() {
        let result = EvaluateHealthInsightUseCase.evaluateBodyFat(newValue: 101)
        #expect(result == nil)
    }

    // MARK: - BMI Update

    @Test("BMI: creates insight for valid value")
    func bmiValid() {
        let result = EvaluateHealthInsightUseCase.evaluateBMI(newValue: 22.5)
        #expect(result != nil)
        #expect(result?.type == .bmiUpdate)
    }

    @Test("BMI: returns nil for zero")
    func bmiZero() {
        let result = EvaluateHealthInsightUseCase.evaluateBMI(newValue: 0)
        #expect(result == nil)
    }

    // MARK: - Workout PR

    @Test("WorkoutPR: creates insight for PR")
    func workoutPRValid() {
        let result = EvaluateHealthInsightUseCase.evaluateWorkoutPR(
            activityName: "Running",
            recordTypeNames: ["Fastest Pace", "Longest Distance"]
        )
        #expect(result != nil)
        #expect(result?.type == .workoutPR)
        #expect(result?.severity == .celebration)
    }

    @Test("WorkoutPR: returns nil for empty record types")
    func workoutPREmpty() {
        let result = EvaluateHealthInsightUseCase.evaluateWorkoutPR(
            activityName: "Running",
            recordTypeNames: []
        )
        #expect(result == nil)
    }

    @Test("WorkoutReward: creates insight from representative reward event")
    func workoutRewardRepresentativeEvent() {
        let event = WorkoutRewardEvent(
            id: "reward-1",
            workoutID: "workout-1",
            activityTypeRawValue: WorkoutActivityType.running.rawValue,
            date: Date(),
            kind: .badgeUnlocked,
            title: "New Badge Unlocked",
            detail: "Running: 10K",
            pointsAwarded: 0,
            levelAfterEvent: nil
        )

        let result = EvaluateHealthInsightUseCase.evaluateWorkoutReward(
            activityName: "Running",
            representativeEvent: event
        )

        #expect(result != nil)
        #expect(result?.type == .workoutPR)
        #expect(result?.severity == .celebration)
        #expect(result?.title == "New Badge Unlocked")
    }
}
