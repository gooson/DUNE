import Foundation
import Testing
@testable import DUNE

// MARK: - HeartRateRecovery Model Tests

@Suite("HeartRateRecovery Model")
struct HeartRateRecoveryModelTests {

    @Test("HRR₁ computed correctly")
    func hrr1Computation() {
        let recovery = HeartRateRecovery(peakHR: 170, recoveryHR: 140)
        #expect(recovery.hrr1 == 30)
    }

    @Test("Rating good when HRR₁ > 20")
    func ratingGood() {
        let recovery = HeartRateRecovery(peakHR: 160, recoveryHR: 130)
        #expect(recovery.rating == .good)
        #expect(recovery.hrr1 == 30)
    }

    @Test("Rating normal when HRR₁ between 12 and 20")
    func ratingNormal() {
        let recovery = HeartRateRecovery(peakHR: 160, recoveryHR: 145)
        #expect(recovery.rating == .normal)
        #expect(recovery.hrr1 == 15)
    }

    @Test("Rating low when HRR₁ < 12")
    func ratingLow() {
        let recovery = HeartRateRecovery(peakHR: 160, recoveryHR: 153)
        #expect(recovery.rating == .low)
        #expect(recovery.hrr1 == 7)
    }

    @Test("Boundary: HRR₁ = 12 is normal (not low)")
    func boundaryTwelve() {
        let recovery = HeartRateRecovery(peakHR: 160, recoveryHR: 148)
        #expect(recovery.hrr1 == 12)
        #expect(recovery.rating == .normal)
    }

    @Test("Boundary: HRR₁ = 20 is normal (not good)")
    func boundaryTwenty() {
        let recovery = HeartRateRecovery(peakHR: 160, recoveryHR: 140)
        #expect(recovery.hrr1 == 20)
        #expect(recovery.rating == .normal)
    }

    @Test("Boundary: HRR₁ = 21 is good")
    func boundaryTwentyOne() {
        let recovery = HeartRateRecovery(peakHR: 160, recoveryHR: 139)
        #expect(recovery.hrr1 == 21)
        #expect(recovery.rating == .good)
    }

    @Test("Boundary: HRR₁ = 11 is low")
    func boundaryEleven() {
        let recovery = HeartRateRecovery(peakHR: 160, recoveryHR: 149)
        #expect(recovery.hrr1 == 11)
        #expect(recovery.rating == .low)
    }
}

// MARK: - computeRecovery Static Method Tests

@Suite("HeartRateQueryService.computeRecovery")
struct HeartRateRecoveryComputeTests {
    private let baseDate = Date(timeIntervalSinceReferenceDate: 100_000)

    @Test("Normal case: peak 170, recovery at 60s")
    func normalCase() {
        let samples: [(bpm: Double, date: Date)] = [
            (bpm: 165, date: baseDate.addingTimeInterval(-30)),
            (bpm: 170, date: baseDate.addingTimeInterval(-10)),
            (bpm: 160, date: baseDate),
            (bpm: 145, date: baseDate.addingTimeInterval(50)),
            (bpm: 140, date: baseDate.addingTimeInterval(60)),
            (bpm: 135, date: baseDate.addingTimeInterval(70)),
        ]

        let result = HeartRateQueryService.computeRecovery(
            samples: samples,
            workoutEndDate: baseDate
        )

        #expect(result != nil)
        #expect(result?.peakHR == 170)
        // recoveryHR = avg of samples at 50s, 60s, 70s = (145+140+135)/3
        let expectedRecovery = (145.0 + 140.0 + 135.0) / 3.0
        #expect(result?.recoveryHR == expectedRecovery)
    }

    @Test("No peak samples returns nil")
    func noPeakSamples() {
        // Only post-workout samples, no pre-end samples
        let samples: [(bpm: Double, date: Date)] = [
            (bpm: 140, date: baseDate.addingTimeInterval(50)),
            (bpm: 135, date: baseDate.addingTimeInterval(60)),
        ]

        let result = HeartRateQueryService.computeRecovery(
            samples: samples,
            workoutEndDate: baseDate
        )

        #expect(result == nil)
    }

    @Test("No recovery samples returns nil")
    func noRecoverySamples() {
        // Only pre-end samples, no post-workout samples in 45-75s window
        let samples: [(bpm: Double, date: Date)] = [
            (bpm: 170, date: baseDate.addingTimeInterval(-10)),
            (bpm: 160, date: baseDate),
        ]

        let result = HeartRateQueryService.computeRecovery(
            samples: samples,
            workoutEndDate: baseDate
        )

        #expect(result == nil)
    }

    @Test("Peak < recovery returns nil")
    func peakLessThanRecovery() {
        let samples: [(bpm: Double, date: Date)] = [
            (bpm: 100, date: baseDate.addingTimeInterval(-10)),
            (bpm: 150, date: baseDate.addingTimeInterval(60)),
        ]

        let result = HeartRateQueryService.computeRecovery(
            samples: samples,
            workoutEndDate: baseDate
        )

        #expect(result == nil)
    }

    @Test("Empty samples returns nil")
    func emptySamples() {
        let result = HeartRateQueryService.computeRecovery(
            samples: [],
            workoutEndDate: baseDate
        )

        #expect(result == nil)
    }

    @Test("Recovery window boundaries are correct (45-75s)")
    func recoveryWindowBoundaries() {
        let samples: [(bpm: Double, date: Date)] = [
            (bpm: 170, date: baseDate.addingTimeInterval(-10)),
            // At 44s — should be excluded
            (bpm: 155, date: baseDate.addingTimeInterval(44)),
            // At 45s — should be included
            (bpm: 140, date: baseDate.addingTimeInterval(45)),
            // At 75s — should be included
            (bpm: 130, date: baseDate.addingTimeInterval(75)),
            // At 76s — should be excluded
            (bpm: 120, date: baseDate.addingTimeInterval(76)),
        ]

        let result = HeartRateQueryService.computeRecovery(
            samples: samples,
            workoutEndDate: baseDate
        )

        #expect(result != nil)
        #expect(result?.peakHR == 170)
        // Only 45s and 75s samples: (140 + 130) / 2 = 135
        #expect(result?.recoveryHR == 135)
    }
}
