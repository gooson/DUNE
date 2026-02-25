import Foundation
import Testing
@testable import DUNE

@Suite("RecoveryModifierService")
struct RecoveryModifierServiceTests {

    let service = RecoveryModifierService()

    // MARK: - Sleep Modifier

    @Test("sleep modifier returns 1.0 when no data")
    func sleepNoData() {
        let result = service.calculateSleepModifier(
            totalSleepMinutes: nil,
            deepSleepRatio: nil,
            remSleepRatio: nil
        )
        #expect(result == 1.0)
    }

    @Test("8+ hours sleep gives high modifier")
    func sleep8Hours() {
        let result = service.calculateSleepModifier(
            totalSleepMinutes: 480, // 8 hours
            deepSleepRatio: nil,
            remSleepRatio: nil
        )
        #expect(result == 1.15)
    }

    @Test("7 hours sleep gives baseline modifier")
    func sleep7Hours() {
        let result = service.calculateSleepModifier(
            totalSleepMinutes: 420,
            deepSleepRatio: nil,
            remSleepRatio: nil
        )
        #expect(result == 1.0)
    }

    @Test("5 hours sleep gives low modifier")
    func sleep5Hours() {
        let result = service.calculateSleepModifier(
            totalSleepMinutes: 300,
            deepSleepRatio: nil,
            remSleepRatio: nil
        )
        #expect(result == 0.70)
    }

    @Test("under 5 hours sleep gives minimum modifier")
    func sleepUnder5Hours() {
        let result = service.calculateSleepModifier(
            totalSleepMinutes: 180, // 3 hours
            deepSleepRatio: nil,
            remSleepRatio: nil
        )
        #expect(result == 0.55)
    }

    @Test("good deep + REM ratios add quality bonus")
    func sleepQualityBonus() {
        let result = service.calculateSleepModifier(
            totalSleepMinutes: 480,
            deepSleepRatio: 0.25,
            remSleepRatio: 0.25
        )
        // 1.15 base + 0.05 deep + 0.05 REM = 1.25
        #expect(result == 1.25)
    }

    @Test("poor deep + REM ratios subtract quality penalty")
    func sleepQualityPenalty() {
        let result = service.calculateSleepModifier(
            totalSleepMinutes: 420,
            deepSleepRatio: 0.05,
            remSleepRatio: 0.05
        )
        // 1.0 base - 0.05 deep - 0.05 REM = 0.90
        #expect(result == 0.90)
    }

    @Test("modifier clamped to 0.5...1.25 range")
    func sleepModifierClamped() {
        let high = service.calculateSleepModifier(
            totalSleepMinutes: 600, // 10 hours
            deepSleepRatio: 0.30,
            remSleepRatio: 0.30
        )
        #expect(high <= 1.25)

        let low = service.calculateSleepModifier(
            totalSleepMinutes: 60, // 1 hour
            deepSleepRatio: 0.01,
            remSleepRatio: 0.01
        )
        #expect(low >= 0.5)
    }

    // MARK: - Readiness Modifier

    @Test("readiness modifier returns 1.0 when no data")
    func readinessNoData() {
        let result = service.calculateReadinessModifier(hrvZScore: nil, rhrDelta: nil)
        #expect(result == 1.0)
    }

    @Test("high HRV z-score gives high readiness")
    func readinessHighHRV() {
        let result = service.calculateReadinessModifier(hrvZScore: 1.5, rhrDelta: nil)
        #expect(result == 1.15)
    }

    @Test("low HRV z-score gives low readiness")
    func readinessLowHRV() {
        let result = service.calculateReadinessModifier(hrvZScore: -1.5, rhrDelta: nil)
        #expect(result == 0.70)
    }

    @Test("elevated RHR delta reduces readiness")
    func readinessElevatedRHR() {
        let result = service.calculateReadinessModifier(hrvZScore: nil, rhrDelta: 8.0)
        #expect(result == 0.85)
    }

    @Test("RHR delta alone with no HRV — lower RHR is good")
    func readinessLowerRHR() {
        let result = service.calculateReadinessModifier(hrvZScore: nil, rhrDelta: -3.0)
        #expect(result == 1.05)
    }

    @Test("combined HRV + RHR adjustment")
    func readinessCombined() {
        // High HRV + elevated RHR — RHR caps the benefit
        let result = service.calculateReadinessModifier(hrvZScore: 1.5, rhrDelta: 6.0)
        #expect(result == 0.75) // min(1.15, 0.75) due to elevated RHR
    }

    @Test("readiness modifier clamped to 0.6...1.20 range")
    func readinessModifierClamped() {
        let high = service.calculateReadinessModifier(hrvZScore: 3.0, rhrDelta: -5.0)
        #expect(high <= 1.20)

        let low = service.calculateReadinessModifier(hrvZScore: -3.0, rhrDelta: 10.0)
        #expect(low >= 0.6)
    }

    @Test("NaN HRV z-score treated as unavailable")
    func readinessNaN() {
        let result = service.calculateReadinessModifier(hrvZScore: .nan, rhrDelta: nil)
        #expect(result == 1.0)
    }
}
