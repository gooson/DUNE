import Testing
import Foundation
@testable import DUNE

@Suite("HealthDataAggregator")
struct HealthDataAggregatorTests {

    private let calendar = Calendar.current

    private func makePoints(_ values: [(Int, Double)]) -> [ChartDataPoint] {
        let base = calendar.startOfDay(for: Date())
        return values.map { dayOffset, value in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: base)!
            return ChartDataPoint(date: date, value: value)
        }
    }

    // MARK: - aggregateByAverage

    @Test("empty data returns empty")
    func averageEmpty() {
        let result = HealthDataAggregator.aggregateByAverage([], unit: .day)
        #expect(result.isEmpty)
    }

    @Test("aggregateByAverage groups by day correctly")
    func averageByDay() {
        let base = calendar.startOfDay(for: Date())
        let points = [
            ChartDataPoint(date: base, value: 10),
            ChartDataPoint(date: base.addingTimeInterval(3600), value: 20),
            ChartDataPoint(date: base.addingTimeInterval(7200), value: 30),
        ]
        let result = HealthDataAggregator.aggregateByAverage(points, unit: .day)
        #expect(result.count == 1)
        #expect(result.first!.value == 20.0) // (10+20+30)/3
    }

    @Test("aggregateByAverage groups by month")
    func averageByMonth() {
        let jan = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let feb = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!
        let points = [
            ChartDataPoint(date: jan, value: 100),
            ChartDataPoint(date: feb, value: 200),
        ]
        let result = HealthDataAggregator.aggregateByAverage(points, unit: .month)
        #expect(result.count == 2)
    }

    // MARK: - aggregateBySum

    @Test("aggregateBySum sums values within same day")
    func sumByDay() {
        let base = calendar.startOfDay(for: Date())
        let points = [
            ChartDataPoint(date: base, value: 5000),
            ChartDataPoint(date: base.addingTimeInterval(3600), value: 3000),
        ]
        let result = HealthDataAggregator.aggregateBySum(points, unit: .day)
        #expect(result.count == 1)
        #expect(result.first!.value == 8000.0)
    }

    @Test("aggregateBySum empty returns empty")
    func sumEmpty() {
        let result = HealthDataAggregator.aggregateBySum([], unit: .day)
        #expect(result.isEmpty)
    }

    // MARK: - aggregateRangeData

    @Test("aggregateRangeData merges ranges by month")
    func rangeByMonth() {
        let jan1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let jan2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 20))!
        let ranges = [
            RangeDataPoint(date: jan1, min: 60, max: 70, average: 65),
            RangeDataPoint(date: jan2, min: 55, max: 75, average: 66),
        ]
        let result = HealthDataAggregator.aggregateRangeData(ranges, unit: .month)
        #expect(result.count == 1)
        #expect(result.first!.min == 55.0) // global min
        #expect(result.first!.max == 75.0) // global max
    }

    // MARK: - computeSummary

    @Test("computeSummary with valid values")
    func summaryValid() {
        let summary = HealthDataAggregator.computeSummary(from: [10, 20, 30])
        #expect(summary != nil)
        #expect(summary!.average == 20.0)
        #expect(summary!.min == 10.0)
        #expect(summary!.max == 30.0)
        #expect(summary!.sum == 60.0)
        #expect(summary!.count == 3)
    }

    @Test("computeSummary with empty returns nil")
    func summaryEmpty() {
        #expect(HealthDataAggregator.computeSummary(from: []) == nil)
    }

    @Test("computeSummary with previous period calculates change")
    func summaryWithPrevious() {
        let summary = HealthDataAggregator.computeSummary(
            from: [100, 110, 120],
            previousPeriodValues: [80, 90, 100]
        )
        #expect(summary != nil)
        #expect(summary!.previousPeriodAverage != nil)
        #expect(summary!.previousPeriodAverage! == 90.0)
        // changePercentage = ((110 - 90) / 90) * 100 ≈ 22.2%
        #expect(summary!.changePercentage != nil)
        let change = summary!.changePercentage!
        #expect(change > 22.0 && change < 23.0)
    }

    @Test("computeSummary without previous period has nil changePercentage")
    func summaryNoPrevious() {
        let summary = HealthDataAggregator.computeSummary(from: [50, 60])
        #expect(summary!.previousPeriodAverage == nil)
        #expect(summary!.changePercentage == nil)
    }

    // MARK: - previousPeriodRange

    @Test("previousPeriodRange returns range before current")
    func previousRange() {
        let range = HealthDataAggregator.previousPeriodRange(for: .week)
        let current = TimePeriod.week.dateRange
        // Previous period end should match current period start
        #expect(abs(range.end.timeIntervalSince(current.start)) < 1)
        // Duration should be roughly the same
        let currentDuration = current.end.timeIntervalSince(current.start)
        let prevDuration = range.end.timeIntervalSince(range.start)
        #expect(abs(currentDuration - prevDuration) < 1)
    }

    // MARK: - intervalComponents

    @Test("intervalComponents returns correct intervals")
    func intervals() {
        let day = HealthDataAggregator.intervalComponents(for: .day)
        #expect(day.hour == 1)

        let week = HealthDataAggregator.intervalComponents(for: .week)
        #expect(week.day == 1)

        let month = HealthDataAggregator.intervalComponents(for: .month)
        #expect(month.day == 1)

        let sixMonths = HealthDataAggregator.intervalComponents(for: .sixMonths)
        #expect(sixMonths.weekOfYear == 1)

        let year = HealthDataAggregator.intervalComponents(for: .year)
        #expect(year.month == 1)
    }

    // MARK: - Edge Cases

    @Test("single value aggregation")
    func singleValue() {
        let points = [ChartDataPoint(date: Date(), value: 42)]
        let result = HealthDataAggregator.aggregateByAverage(points, unit: .day)
        #expect(result.count == 1)
        #expect(result.first!.value == 42.0)
    }

    @Test("aggregation sorts by date ascending")
    func sortOrder() {
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let points = [
            ChartDataPoint(date: now, value: 20),
            ChartDataPoint(date: yesterday, value: 10),
        ]
        let result = HealthDataAggregator.aggregateByAverage(points, unit: .day)
        #expect(result.count == 2)
        #expect(result.first!.date < result.last!.date)
    }
}
