import Foundation
import Testing
@testable import DUNE

@Suite("WeeklyHeroTrendPoint")
struct WeeklyHeroTrendPointTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 12))!
    }

    private func current(_ date: Date, score: Int = 67) -> TrainingReadiness {
        TrainingReadiness(score: score, components: .init(hrvScore: 50, rhrScore: 50, sleepScore: 80, fatigueScore: 70, trendBonus: 50), evaluationDate: date)
    }

    @Test("Seven calendar days span DST and missing days stay nil")
    func missingDaysAndDST() {
        let result = WeeklyHeroTrendPoint.readinessHistory(samples: [], current: current(now), referenceDate: now, calendar: calendar)
        #expect(result.count == 7)
        #expect(result.map { calendar.component(.day, from: $0.date) } == [3, 4, 5, 6, 7, 8, 9])
        #expect(result.dropLast().allSatisfy { $0.value == nil })
        #expect(result.last?.value == 67)
        #expect(result[6].date.timeIntervalSince(result[5].date) == 23 * 3600)
    }

    @Test("Latest valid saved score wins, while today matches the ring")
    func latestAndCurrent() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let result = WeeklyHeroTrendPoint.readinessHistory(samples: [
            DailySample(date: yesterday, value: 72),
            DailySample(date: yesterday.addingTimeInterval(-3600), value: 65),
            DailySample(date: now.addingTimeInterval(-3600), value: 99)
        ], current: current(now), referenceDate: now, calendar: calendar)
        #expect(result[5].value == 72)
        #expect(result[6].value == 67)
    }

    @Test("Invalid, future, and out-of-window values are not records")
    func invalidSamples() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let old = calendar.date(byAdding: .day, value: -8, to: now)!
        let result = WeeklyHeroTrendPoint.readinessHistory(samples: [
            DailySample(date: yesterday, value: .nan),
            DailySample(date: yesterday, value: .infinity),
            DailySample(date: yesterday, value: -1),
            DailySample(date: yesterday, value: 101),
            DailySample(date: old, value: 80),
            DailySample(date: now.addingTimeInterval(3600), value: 90)
        ], current: nil, referenceDate: now, calendar: calendar)
        #expect(result.allSatisfy { $0.value == nil })
    }

    @Test("Zero is a real score and yesterday's current score is not today")
    func zeroAndStaleCurrent() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let result = WeeklyHeroTrendPoint.readinessHistory(samples: [DailySample(date: yesterday, value: 0)], current: current(yesterday), referenceDate: now, calendar: calendar)
        #expect(result[5].value == 0)
        #expect(result[6].value == nil)
    }
}
