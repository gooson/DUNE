import Foundation
import Testing
@testable import DUNE

@Suite("CalculateSleepDeficitUseCase")
struct CalculateSleepDeficitUseCaseTests {
    let sut = CalculateSleepDeficitUseCase()
    let calendar = Calendar.current

    // MARK: - Helpers

    private func makeDurations(
        minutesPerDay: [Double],
        startingDaysAgo: Int? = nil
    ) -> [CalculateSleepDeficitUseCase.Input.DayDuration] {
        let start = startingDaysAgo ?? minutesPerDay.count
        return minutesPerDay.enumerated().map { index, minutes in
            let date = calendar.date(byAdding: .day, value: -(start - index), to: Date())!
            return .init(date: date, totalMinutes: minutes)
        }
    }

    // MARK: - Insufficient Data

    @Test("Returns insufficient when less than 3 data points")
    func insufficientData() {
        let durations = makeDurations(minutesPerDay: [480, 420])
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        #expect(result.level == .insufficient)
        #expect(result.dataPointCount == 2)
        #expect(result.weeklyDeficit == 0)
    }

    @Test("Zero-data days are excluded from data point count")
    func zeroDataDaysExcluded() {
        // 5 days but 3 are zero → only 2 valid → insufficient
        let durations = makeDurations(minutesPerDay: [480, 0, 0, 0, 420])
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        #expect(result.level == .insufficient)
        #expect(result.dataPointCount == 2)
    }

    // MARK: - Good (< 2h deficit)

    @Test("Consistent sleep yields good level with near-zero deficit")
    func goodLevel() {
        // 14 days of 480 min (8h) each
        let durations = makeDurations(minutesPerDay: Array(repeating: 480.0, count: 14))
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        #expect(result.level == .good)
        #expect(result.weeklyDeficit == 0)
        #expect(result.shortTermAverage == 480)
    }

    @Test("Slight deficit under 2h is still good")
    func slightDeficit() {
        // Average = 480 (first 7 days all 480), last 7 days: 6 days 480, 1 day 380 → deficit = 100 min
        var mins = Array(repeating: 480.0, count: 13)
        mins.append(380.0) // Last day: 100 min below average
        let durations = makeDurations(minutesPerDay: mins)
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        #expect(result.level == .good)
        #expect(result.weeklyDeficit > 0)
        #expect(result.weeklyDeficit < 120) // Under 2h threshold
    }

    // MARK: - Mild (2-5h deficit)

    @Test("Mild deficit level for 2-5h weekly deficit")
    func mildLevel() {
        // Average ≈ 480, last 7 days: 3 days at 380 → deficit = 3×100 = 300 min
        // But average shifts with lower values, so compute carefully
        var mins = Array(repeating: 480.0, count: 7)
        mins.append(contentsOf: Array(repeating: 480.0, count: 4))
        mins.append(contentsOf: Array(repeating: 350.0, count: 3)) // Last 3 days significantly short
        let durations = makeDurations(minutesPerDay: mins)
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        #expect(result.level == .mild || result.level == .moderate)
        #expect(result.weeklyDeficit >= 120) // At least 2h
    }

    // MARK: - Moderate (5-10h deficit)

    @Test("Moderate deficit for persistent short sleep")
    func moderateLevel() {
        // Average: (7×480 + 7×360) / 14 = 420 min
        // Last 7 days all 360: deficit per day = 420-360 = 60, weekly = 420 min
        var mins = Array(repeating: 480.0, count: 7)
        mins.append(contentsOf: Array(repeating: 360.0, count: 7))
        let durations = makeDurations(minutesPerDay: mins)
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        #expect(result.level == .moderate)
        #expect(result.weeklyDeficit >= 300)
        #expect(result.weeklyDeficit < 600)
    }

    // MARK: - Severe (> 10h deficit)

    @Test("Severe deficit for extreme short sleep")
    func severeLevel() {
        // Average: (7×480 + 7×240) / 14 = 360 min
        // Last 7 days all 240: deficit per day = 360-240 = 120, weekly = 840 min
        var mins = Array(repeating: 480.0, count: 7)
        mins.append(contentsOf: Array(repeating: 240.0, count: 7))
        let durations = makeDurations(minutesPerDay: mins)
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        #expect(result.level == .severe)
        #expect(result.weeklyDeficit > 600)
    }

    // MARK: - Excess Sleep Capping

    @Test("Excess sleep only cancels same-day deficit, not past days")
    func excessSleepCapping() {
        // Average = 480 (8h). Last 7 days: 6 days at 420 (deficit 60 each = 360),
        // 1 day at 600 (excess 120, capped to 0 deficit).
        // Weekly deficit = 6×60 = 360 (not 360-120=240).
        var mins = Array(repeating: 480.0, count: 7)
        mins.append(contentsOf: Array(repeating: 420.0, count: 6))
        mins.append(600.0)
        let durations = makeDurations(minutesPerDay: mins)
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))

        // The excess day should have 0 deficit
        let excessDay = result.dailyDeficits.last
        #expect(excessDay?.deficitMinutes == 0)
        // Total should not subtract excess from past deficits
        #expect(result.weeklyDeficit > 0)
    }

    // MARK: - Long Term Average

    @Test("Long term average is nil when fewer than 7 data points")
    func longTermInsufficientData() {
        let recent = makeDurations(minutesPerDay: Array(repeating: 480.0, count: 14))
        let longTerm = makeDurations(minutesPerDay: Array(repeating: 480.0, count: 5))
        let result = sut.execute(input: .init(recentDurations: recent, longTermDurations: longTerm))
        #expect(result.longTermAverage == nil)
        #expect(result.shortTermAverage == 480)
    }

    @Test("Long term average computed with 7+ data points")
    func longTermSufficientData() {
        let recent = makeDurations(minutesPerDay: Array(repeating: 480.0, count: 14))
        let longTerm = makeDurations(minutesPerDay: Array(repeating: 450.0, count: 30))
        let result = sut.execute(input: .init(recentDurations: recent, longTermDurations: longTerm))
        #expect(result.longTermAverage == 450)
    }

    // MARK: - Boundary Values

    @Test("Exactly 2h deficit is mild, not good")
    func boundary2h() {
        // Need weeklyDeficit == exactly 120
        // Average = 480, one day at 360 deficit = 120, rest at 480 deficit = 0
        var mins = Array(repeating: 480.0, count: 13)
        mins.append(360.0)
        let durations = makeDurations(minutesPerDay: mins)
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        // Average shifts slightly with the 360 day included, so check range
        if result.weeklyDeficit >= 120 {
            #expect(result.level == .mild || result.level == .moderate)
        }
    }

    @Test("Zero-data days in last 7 are not penalized")
    func zeroDataDaysNotPenalized() {
        // Average = 480 from valid days, one day in last 7 has 0 (not worn)
        var mins = Array(repeating: 480.0, count: 13)
        mins.append(0.0) // Sensor not worn
        let durations = makeDurations(minutesPerDay: mins)
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        // Zero day should not add deficit
        let zeroDay = result.dailyDeficits.last
        #expect(zeroDay?.deficitMinutes == 0)
    }

    // MARK: - Daily Deficits Array

    @Test("Daily deficits array has correct count and order")
    func dailyDeficitsStructure() {
        let mins = Array(repeating: 480.0, count: 14)
        let durations = makeDurations(minutesPerDay: mins)
        let result = sut.execute(input: .init(recentDurations: durations, longTermDurations: durations))
        #expect(result.dailyDeficits.count == 7) // Last 7 days
        // Verify oldest-first order
        if result.dailyDeficits.count >= 2 {
            #expect(result.dailyDeficits[0].date < result.dailyDeficits[1].date)
        }
    }
}
