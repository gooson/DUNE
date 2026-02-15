import Foundation
import Testing
@testable import Dailve

@Suite("ChartDataPoint")
struct ChartDataPointTests {
    @Test("id is derived from date")
    func idIsDate() {
        let date = Date()
        let point = ChartDataPoint(date: date, value: 42.0)
        #expect(point.id == date)
    }
}

@Suite("RangeDataPoint")
struct RangeDataPointTests {
    @Test("id is derived from date")
    func idIsDate() {
        let date = Date()
        let point = RangeDataPoint(date: date, min: 60, max: 80, average: 70)
        #expect(point.id == date)
    }
}

@Suite("StackedDataPoint")
struct StackedDataPointTests {
    @Test("total sums all segment values")
    func totalSums() {
        let point = StackedDataPoint(
            id: "test",
            date: Date(),
            segments: [
                .init(category: "Deep", value: 3600),
                .init(category: "Core", value: 7200),
                .init(category: "REM", value: 5400),
            ]
        )
        #expect(point.total == 16200)
    }

    @Test("total is zero with no segments")
    func totalZero() {
        let point = StackedDataPoint(id: "empty", date: Date(), segments: [])
        #expect(point.total == 0)
    }
}

@Suite("MetricSummary")
struct MetricSummaryTests {
    @Test("changePercentage calculates correctly")
    func changePercentage() {
        let summary = MetricSummary(
            average: 60,
            min: 50,
            max: 70,
            sum: 420,
            count: 7,
            previousPeriodAverage: 50
        )
        // (60 - 50) / 50 * 100 = 20%
        #expect(summary.changePercentage! == 20.0)
    }

    @Test("changePercentage is nil when no previous data")
    func changePercentageNil() {
        let summary = MetricSummary(
            average: 60,
            min: 50,
            max: 70,
            sum: 420,
            count: 7,
            previousPeriodAverage: nil
        )
        #expect(summary.changePercentage == nil)
    }

    @Test("changePercentage is nil when previous average is zero")
    func changePercentageZeroPrevious() {
        let summary = MetricSummary(
            average: 60,
            min: 50,
            max: 70,
            sum: 420,
            count: 7,
            previousPeriodAverage: 0
        )
        #expect(summary.changePercentage == nil)
    }

    @Test("negative changePercentage for decrease")
    func negativeChangePercentage() {
        let summary = MetricSummary(
            average: 40,
            min: 30,
            max: 50,
            sum: 280,
            count: 7,
            previousPeriodAverage: 50
        )
        // (40 - 50) / 50 * 100 = -20%
        #expect(summary.changePercentage! == -20.0)
    }
}

@Suite("Highlight")
struct HighlightTests {
    @Test("id is composed of type and date")
    func idComposition() {
        let date = Date()
        let highlight = Highlight(type: .high, value: 100, date: date, label: "Highest")
        #expect(highlight.id.contains("high"))
    }
}
