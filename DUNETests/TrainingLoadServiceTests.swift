import Foundation
import Testing
@testable import DUNE

@Suite("TrainingLoadService")
struct TrainingLoadServiceTests {

    // MARK: - Source Selection

    @Test("Prefers effort score when available")
    func prefersEffort() {
        let source = TrainingLoadService.calculateLoad(
            effortScore: 7.0,
            rpe: 5,
            durationMinutes: 30,
            heartRateAvg: 150,
            restingHR: 60,
            maxHR: 190
        )
        #expect(source == .effort)
    }

    @Test("Falls back to RPE when no effort score")
    func fallsBackToRPE() {
        let source = TrainingLoadService.calculateLoad(
            effortScore: nil,
            rpe: 7,
            durationMinutes: 30,
            heartRateAvg: 150,
            restingHR: 60,
            maxHR: 190
        )
        #expect(source == .rpe)
    }

    @Test("Falls back to TRIMP when no effort or RPE")
    func fallsBackToTRIMP() {
        let source = TrainingLoadService.calculateLoad(
            effortScore: nil,
            rpe: nil,
            durationMinutes: 30,
            heartRateAvg: 150,
            restingHR: 60,
            maxHR: 190
        )
        #expect(source == .trimp)
    }

    @Test("Returns nil when no data available")
    func returnsNilNoData() {
        let source = TrainingLoadService.calculateLoad(
            effortScore: nil,
            rpe: nil,
            durationMinutes: 30,
            heartRateAvg: nil,
            restingHR: nil,
            maxHR: nil
        )
        #expect(source == nil)
    }

    @Test("Returns nil for zero duration")
    func nilForZeroDuration() {
        let source = TrainingLoadService.calculateLoad(
            effortScore: 7.0,
            rpe: nil,
            durationMinutes: 0,
            heartRateAvg: nil,
            restingHR: nil,
            maxHR: nil
        )
        #expect(source == nil)
    }

    @Test("Rejects effort score out of range")
    func rejectsInvalidEffort() {
        let source = TrainingLoadService.calculateLoad(
            effortScore: 0,
            rpe: nil,
            durationMinutes: 30,
            heartRateAvg: nil,
            restingHR: nil,
            maxHR: nil
        )
        #expect(source == nil)

        let source2 = TrainingLoadService.calculateLoad(
            effortScore: 11,
            rpe: nil,
            durationMinutes: 30,
            heartRateAvg: nil,
            restingHR: nil,
            maxHR: nil
        )
        #expect(source2 == nil)
    }

    @Test("Rejects RPE out of range")
    func rejectsInvalidRPE() {
        let source = TrainingLoadService.calculateLoad(
            effortScore: nil,
            rpe: 0,
            durationMinutes: 30,
            heartRateAvg: nil,
            restingHR: nil,
            maxHR: nil
        )
        #expect(source == nil)
    }

    // MARK: - Load Computation

    @Test("Effort-based load calculation")
    func effortLoadCalculation() {
        // effort=7, 60min → 7 * 60/60 = 7.0
        let load = TrainingLoadService.computeLoadValue(
            source: .effort,
            effortScore: 7.0,
            rpe: nil,
            durationMinutes: 60,
            heartRateAvg: nil,
            restingHR: nil,
            maxHR: nil
        )
        #expect(abs(load - 7.0) < 0.01)
    }

    @Test("RPE-based load calculation")
    func rpeLoadCalculation() {
        // rpe=8, 45min → 8 * 45/60 = 6.0
        let load = TrainingLoadService.computeLoadValue(
            source: .rpe,
            effortScore: nil,
            rpe: 8,
            durationMinutes: 45,
            heartRateAvg: nil,
            restingHR: nil,
            maxHR: nil
        )
        #expect(abs(load - 6.0) < 0.01)
    }

    @Test("TRIMP-based load calculation")
    func trimpLoadCalculation() {
        // avgHR=150, restHR=60, maxHR=190
        // hrRatio = (150-60)/(190-60) = 90/130 ≈ 0.6923
        // load = 30 * 0.6923² ≈ 30 * 0.4793 ≈ 14.378
        let load = TrainingLoadService.computeLoadValue(
            source: .trimp,
            effortScore: nil,
            rpe: nil,
            durationMinutes: 30,
            heartRateAvg: 150,
            restingHR: 60,
            maxHR: 190
        )
        #expect(load > 14.0)
        #expect(load < 15.0)
    }

    @Test("TRIMP returns 0 when maxHR <= restHR")
    func trimpInvalidHR() {
        let load = TrainingLoadService.computeLoadValue(
            source: .trimp,
            effortScore: nil,
            rpe: nil,
            durationMinutes: 30,
            heartRateAvg: 150,
            restingHR: 190,
            maxHR: 60
        )
        #expect(load == 0)
    }

    @Test("TRIMP returns 0 when avgHR < restHR")
    func trimpAvgBelowRest() {
        let load = TrainingLoadService.computeLoadValue(
            source: .trimp,
            effortScore: nil,
            rpe: nil,
            durationMinutes: 30,
            heartRateAvg: 50,
            restingHR: 60,
            maxHR: 190
        )
        #expect(load == 0)
    }
}
