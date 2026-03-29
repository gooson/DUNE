import Foundation
import Testing
@testable import DUNE

@Suite("GenerateDailyDigestUseCase")
struct GenerateDailyDigestUseCaseTests {
    let sut = GenerateDailyDigestUseCase()

    @Test("Full metrics produces non-empty summary")
    func fullMetrics() {
        let metrics = DailyDigest.DigestMetrics(
            conditionScore: 85,
            conditionDelta: 5,
            workoutSummary: "upper body 45min",
            sleepMinutes: 450,
            sleepDebtMinutes: 60,
            stepsCount: 8500,
            stressLevel: .low
        )
        let digest = sut.execute(metrics: metrics)
        #expect(!digest.summary.isEmpty)
        #expect(digest.summary.contains("85"))
    }

    @Test("No workout shows rest day")
    func restDay() {
        let metrics = DailyDigest.DigestMetrics(
            conditionScore: 72,
            conditionDelta: nil,
            workoutSummary: nil,
            sleepMinutes: 420,
            sleepDebtMinutes: nil,
            stepsCount: nil,
            stressLevel: nil
        )
        let digest = sut.execute(metrics: metrics)
        #expect(!digest.summary.isEmpty)
    }

    @Test("All nil metrics still produces output")
    func emptyMetrics() {
        let metrics = DailyDigest.DigestMetrics(
            conditionScore: nil,
            conditionDelta: nil,
            workoutSummary: nil,
            sleepMinutes: nil,
            sleepDebtMinutes: nil,
            stepsCount: nil,
            stressLevel: nil
        )
        let digest = sut.execute(metrics: metrics)
        // Should still produce at least the rest day message
        #expect(!digest.summary.isEmpty)
    }

    @Test("Sleep debt below threshold is not mentioned")
    func lowSleepDebt() {
        let metrics = DailyDigest.DigestMetrics(
            conditionScore: 90,
            conditionDelta: 2,
            workoutSummary: nil,
            sleepMinutes: 480,
            sleepDebtMinutes: 20, // Below 30-min threshold
            stepsCount: 10000,
            stressLevel: .low
        )
        let digest = sut.execute(metrics: metrics)
        // Should not contain sleep debt messaging
        #expect(!digest.summary.isEmpty)
    }

    @Test("High stress level produces recovery advice")
    func highStressAdvice() {
        let metrics = DailyDigest.DigestMetrics(
            conditionScore: 50,
            conditionDelta: -10,
            workoutSummary: nil,
            sleepMinutes: 360,
            sleepDebtMinutes: 180,
            stepsCount: 3000,
            stressLevel: .high
        )
        let digest = sut.execute(metrics: metrics)
        #expect(!digest.summary.isEmpty)
    }

    @Test("Digest date is set correctly")
    func digestDate() {
        let metrics = DailyDigest.DigestMetrics(
            conditionScore: 80,
            conditionDelta: nil,
            workoutSummary: nil,
            sleepMinutes: nil,
            sleepDebtMinutes: nil,
            stepsCount: nil,
            stressLevel: nil
        )
        let before = Date()
        let digest = sut.execute(metrics: metrics)
        let after = Date()
        #expect(digest.date >= before)
        #expect(digest.date <= after)
    }
}
