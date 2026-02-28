import Foundation
import Testing
@testable import DUNE

@Suite("TrendAnalysisService")
struct TrendAnalysisServiceTests {
    let service = TrendAnalysisService()
    let calendar = Calendar.current

    private func sample(daysAgo: Int, value: Double) -> (date: Date, value: Double) {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return (date: date, value: value)
    }

    // MARK: - Insufficient Data

    @Test("Returns insufficient for empty input")
    func emptyInput() {
        let result = service.analyzeTrend(values: [])
        #expect(result.direction == .insufficient)
    }

    @Test("Returns insufficient for fewer than 3 data points")
    func tooFewDataPoints() {
        let values = [sample(daysAgo: 1, value: 50), sample(daysAgo: 0, value: 55)]
        let result = service.analyzeTrend(values: values)
        #expect(result.direction == .insufficient)
    }

    // MARK: - Rising Trend

    @Test("Detects rising trend with 3+ consecutive increases")
    func risingTrend() {
        let values = [
            sample(daysAgo: 4, value: 40),
            sample(daysAgo: 3, value: 45),
            sample(daysAgo: 2, value: 50),
            sample(daysAgo: 1, value: 55),
            sample(daysAgo: 0, value: 60)
        ]
        let result = service.analyzeTrend(values: values, windowDays: 7)
        #expect(result.direction == .rising)
        #expect(result.consecutiveDays >= 3)
        #expect(result.changePercent > 0)
    }

    // MARK: - Falling Trend

    @Test("Detects falling trend with 3+ consecutive decreases")
    func fallingTrend() {
        let values = [
            sample(daysAgo: 4, value: 60),
            sample(daysAgo: 3, value: 55),
            sample(daysAgo: 2, value: 50),
            sample(daysAgo: 1, value: 45),
            sample(daysAgo: 0, value: 40)
        ]
        let result = service.analyzeTrend(values: values, windowDays: 7)
        #expect(result.direction == .falling)
        #expect(result.consecutiveDays >= 3)
        #expect(result.changePercent < 0)
    }

    // MARK: - Stable

    @Test("Detects stable trend with small oscillations")
    func stableTrend() {
        let values = [
            sample(daysAgo: 4, value: 50),
            sample(daysAgo: 3, value: 51),
            sample(daysAgo: 2, value: 50),
            sample(daysAgo: 1, value: 51),
            sample(daysAgo: 0, value: 50)
        ]
        let result = service.analyzeTrend(values: values, windowDays: 7)
        #expect(result.direction == .stable)
    }

    // MARK: - Edge Cases

    @Test("Handles unsorted input correctly")
    func unsortedInput() {
        // Provide values in random order — should still sort oldest-first (Correction #156)
        let values = [
            sample(daysAgo: 0, value: 60),
            sample(daysAgo: 4, value: 40),
            sample(daysAgo: 2, value: 50),
            sample(daysAgo: 1, value: 55),
            sample(daysAgo: 3, value: 45)
        ]
        let result = service.analyzeTrend(values: values, windowDays: 7)
        #expect(result.direction == .rising)
    }

    @Test("Filters out zero values in deltas")
    func zeroValueSkipped() {
        let values = [
            sample(daysAgo: 4, value: 0),
            sample(daysAgo: 3, value: 50),
            sample(daysAgo: 2, value: 55),
            sample(daysAgo: 1, value: 60),
            sample(daysAgo: 0, value: 65)
        ]
        let result = service.analyzeTrend(values: values, windowDays: 7)
        // Zero prev value is skipped, should still detect rising from remaining
        #expect(result.direction == .rising || result.direction == .stable)
    }

    @Test("Window limits considered data")
    func windowFiltering() {
        // Old data outside window should be excluded
        let values = [
            sample(daysAgo: 30, value: 100),
            sample(daysAgo: 29, value: 90),
            sample(daysAgo: 2, value: 50),
            sample(daysAgo: 1, value: 55),
            sample(daysAgo: 0, value: 60)
        ]
        let result = service.analyzeTrend(values: values, windowDays: 7)
        // Only 3 points in window
        #expect(result.direction != .insufficient)
    }

    @Test("changePercent is finite")
    func changePercentFinite() {
        let values = [
            sample(daysAgo: 3, value: 50),
            sample(daysAgo: 2, value: 55),
            sample(daysAgo: 1, value: 60),
            sample(daysAgo: 0, value: 65)
        ]
        let result = service.analyzeTrend(values: values, windowDays: 7)
        #expect(result.changePercent.isFinite)
    }
}
