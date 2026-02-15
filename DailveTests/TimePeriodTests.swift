import Foundation
import Testing
@testable import Dailve

@Suite("TimePeriod Model")
struct TimePeriodTests {

    // MARK: - dateRange

    @Test("day dateRange starts at start of today")
    func dayDateRange() {
        let range = TimePeriod.day.dateRange
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        #expect(range.start == startOfToday)
        #expect(range.end.timeIntervalSinceNow < 1)
    }

    @Test("week dateRange spans 7 days")
    func weekDateRange() {
        let range = TimePeriod.week.dateRange
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        #expect(days >= 6 && days <= 7)
    }

    @Test("month dateRange spans approximately 30 days")
    func monthDateRange() {
        let range = TimePeriod.month.dateRange
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        #expect(days >= 28 && days <= 31)
    }

    @Test("sixMonths dateRange spans approximately 6 months")
    func sixMonthsDateRange() {
        let range = TimePeriod.sixMonths.dateRange
        let calendar = Calendar.current
        let months = calendar.dateComponents([.month], from: range.start, to: range.end).month ?? 0
        #expect(months >= 5 && months <= 6)
    }

    @Test("year dateRange spans approximately 12 months")
    func yearDateRange() {
        let range = TimePeriod.year.dateRange
        let calendar = Calendar.current
        let months = calendar.dateComponents([.month], from: range.start, to: range.end).month ?? 0
        #expect(months >= 11 && months <= 12)
    }

    @Test("dateRange start is always before end")
    func dateRangeOrder() {
        for period in TimePeriod.allCases {
            let range = period.dateRange
            #expect(range.start < range.end, "Failed for \(period)")
        }
    }

    // MARK: - strideComponent

    @Test("day stride is hour")
    func dayStride() {
        #expect(TimePeriod.day.strideComponent == .hour)
    }

    @Test("week stride is day")
    func weekStride() {
        #expect(TimePeriod.week.strideComponent == .day)
    }

    @Test("month stride is day")
    func monthStride() {
        #expect(TimePeriod.month.strideComponent == .day)
    }

    @Test("sixMonths stride is month")
    func sixMonthsStride() {
        #expect(TimePeriod.sixMonths.strideComponent == .month)
    }

    @Test("year stride is month")
    func yearStride() {
        #expect(TimePeriod.year.strideComponent == .month)
    }

    // MARK: - aggregationUnit

    @Test("day aggregates by hour")
    func dayAggregation() {
        #expect(TimePeriod.day.aggregationUnit == .hour)
    }

    @Test("week aggregates by day")
    func weekAggregation() {
        #expect(TimePeriod.week.aggregationUnit == .day)
    }

    @Test("month aggregates by day")
    func monthAggregation() {
        #expect(TimePeriod.month.aggregationUnit == .day)
    }

    @Test("sixMonths aggregates by week")
    func sixMonthsAggregation() {
        #expect(TimePeriod.sixMonths.aggregationUnit == .weekOfYear)
    }

    @Test("year aggregates by month")
    func yearAggregation() {
        #expect(TimePeriod.year.aggregationUnit == .month)
    }

    // MARK: - expectedPointCount

    @Test("expectedPointCount returns reasonable values")
    func expectedPointCounts() {
        #expect(TimePeriod.day.expectedPointCount == 24)
        #expect(TimePeriod.week.expectedPointCount == 7)
        #expect(TimePeriod.month.expectedPointCount == 30)
        #expect(TimePeriod.sixMonths.expectedPointCount == 26)
        #expect(TimePeriod.year.expectedPointCount == 12)
    }

    // MARK: - CaseIterable

    @Test("allCases contains 5 periods in order")
    func allCases() {
        let cases = TimePeriod.allCases
        #expect(cases.count == 5)
        #expect(cases[0] == .day)
        #expect(cases[4] == .year)
    }

    // MARK: - rawValue

    @Test("rawValue matches display labels")
    func rawValues() {
        #expect(TimePeriod.day.rawValue == "D")
        #expect(TimePeriod.week.rawValue == "W")
        #expect(TimePeriod.month.rawValue == "M")
        #expect(TimePeriod.sixMonths.rawValue == "6M")
        #expect(TimePeriod.year.rawValue == "Y")
    }
}
