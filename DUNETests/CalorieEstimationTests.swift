import Foundation
import Testing
@testable import DUNE

@Suite("CalorieEstimationService")
struct CalorieEstimationTests {
    let service = CalorieEstimationService()

    @Test("Normal calculation produces expected result")
    func normalCalc() {
        // MET 6.0, 70kg, 30min active, 0 rest
        let result = service.estimate(
            metValue: 6.0,
            bodyWeightKg: 70.0,
            durationSeconds: 1800,
            restSeconds: 0
        )
        // 6.0 * 70 * (1800/3600) = 6 * 70 * 0.5 = 210
        #expect(result != nil)
        #expect(abs(result! - 210.0) < 0.01)
    }

    @Test("Rest time is subtracted from duration")
    func restTimeSubtracted() {
        // 30min total, 10min rest = 20min active
        let result = service.estimate(
            metValue: 6.0,
            bodyWeightKg: 70.0,
            durationSeconds: 1800,
            restSeconds: 600
        )
        // 6.0 * 70 * (1200/3600) = 6 * 70 * 0.333... = 140
        #expect(result != nil)
        #expect(abs(result! - 140.0) < 0.01)
    }

    @Test("Returns nil for zero MET value")
    func zeroMET() {
        let result = service.estimate(
            metValue: 0,
            bodyWeightKg: 70,
            durationSeconds: 1800,
            restSeconds: 0
        )
        #expect(result == nil)
    }

    @Test("Returns nil for negative MET value")
    func negativeMET() {
        let result = service.estimate(
            metValue: -1,
            bodyWeightKg: 70,
            durationSeconds: 1800,
            restSeconds: 0
        )
        #expect(result == nil)
    }

    @Test("Returns nil for zero body weight")
    func zeroWeight() {
        let result = service.estimate(
            metValue: 6.0,
            bodyWeightKg: 0,
            durationSeconds: 1800,
            restSeconds: 0
        )
        #expect(result == nil)
    }

    @Test("Returns nil for zero duration")
    func zeroDuration() {
        let result = service.estimate(
            metValue: 6.0,
            bodyWeightKg: 70,
            durationSeconds: 0,
            restSeconds: 0
        )
        #expect(result == nil)
    }

    @Test("Returns nil when rest equals duration")
    func restEqualsDuration() {
        let result = service.estimate(
            metValue: 6.0,
            bodyWeightKg: 70,
            durationSeconds: 1800,
            restSeconds: 1800
        )
        #expect(result == nil)
    }

    @Test("Returns nil when rest exceeds duration")
    func restExceedsDuration() {
        let result = service.estimate(
            metValue: 6.0,
            bodyWeightKg: 70,
            durationSeconds: 1800,
            restSeconds: 3600
        )
        #expect(result == nil)
    }

    @Test("Default body weight constant is 70kg")
    func defaultWeight() {
        #expect(CalorieEstimationService.defaultBodyWeightKg == 70.0)
    }

    @Test("Returns nil for MET value exceeding domain range (>= 30)")
    func metTooHigh() {
        let result = service.estimate(
            metValue: 30,
            bodyWeightKg: 70,
            durationSeconds: 1800,
            restSeconds: 0
        )
        #expect(result == nil)
    }

    @Test("Returns nil for body weight exceeding domain range (>= 500)")
    func weightTooHigh() {
        let result = service.estimate(
            metValue: 6.0,
            bodyWeightKg: 500,
            durationSeconds: 1800,
            restSeconds: 0
        )
        #expect(result == nil)
    }

    @Test("Returns nil for duration exceeding 8 hours (>= 28800s)")
    func durationTooLong() {
        let result = service.estimate(
            metValue: 6.0,
            bodyWeightKg: 70,
            durationSeconds: 28800,
            restSeconds: 0
        )
        #expect(result == nil)
    }
}
