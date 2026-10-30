import Foundation
import Testing
@testable import DUNE

@Suite("MetricVisibleSummary")
struct MetricVisibleSummaryTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func make(
        _ values: [(TimeInterval, Double)], coverage: ClosedRange<TimeInterval> = -100...100,
        limited: TimeInterval? = nil, additive: Bool = false
    ) -> MetricVisibleSummary? {
        MetricVisibleSummary.make(
            points: values.map { ChartDataPoint(date: start.addingTimeInterval($0.0), value: $0.1) },
            start: start, duration: 10,
            coverage: DateInterval(start: start.addingTimeInterval(coverage.lowerBound), end: start.addingTimeInterval(coverage.upperBound)),
            referenceDate: start.addingTimeInterval(100), limitedStart: limited.map { start.addingTimeInterval($0) },
            basis: .measurements, unit: "kg", isAdditive: additive
        )
    }

    @Test("Shared endpoints belong to exactly one window")
    func halfOpen() throws {
        let result = try #require(make([(-10, 4), (0, 10), (9, 20), (10, 900)]))
        #expect(result.statistics.count == 2)
        #expect(result.statistics.average == 15)
        #expect(result.statistics.previousPeriodAverage == 4)
        #expect(result.total == nil)
    }

    @Test("Measurement weights survive unequal plot bucket sizes")
    func measurementWeights() throws {
        // Three measurements on one chart day, one on the next: raw mean 25, bucket mean 50.
        let result = try #require(make([(0, 0), (1, 0), (2, 0), (9, 100)]))
        #expect(result.statistics.average == 25)
        #expect(result.statistics.count == 4)
    }

    @Test("Finite zero and signed observations survive; invalid scalars do not")
    func signedFinite() throws {
        let result = try #require(make([(0, 0), (1, -2), (2, .nan), (3, .infinity)]))
        #expect(result.statistics.count == 2)
        #expect(result.statistics.average == -1)
        #expect(result.statistics.min == -2)
    }

    @Test("Unloaded current suppresses stale statistics; unloaded prior suppresses comparison")
    func coverage() throws {
        #expect(make([(0, 10)], coverage: 1...100) == nil)
        #expect(make([(0, 10)], coverage: -100...9) == nil)
        let result = try #require(make([(-9, 4), (0, 10)], coverage: -9...100))
        #expect(result.statistics.previousPeriodAverage == nil)
    }

    @Test("Limited current stays partial and never compares an unauthorized prior window")
    func limitedHistory() throws {
        let result = try #require(make([(-9, 4), (0, 5), (3, 10)], limited: 2))
        #expect(result.isPartialHistory)
        #expect(result.statistics.count == 1)
        #expect(result.statistics.average == 10)
        #expect(result.statistics.previousPeriodAverage == nil)
    }

    @Test("Totals and average comparisons keep distinct meanings including zero prior")
    func totals() throws {
        let result = try #require(make([(-9, 0), (0, 10), (1, 20)], additive: true))
        #expect(result.total == 30)
        #expect(result.previousTotal == 0)
        #expect(result.statistics.previousPeriodAverage == 0)
        #expect(result.statistics.changePercentage == nil)
        #expect(make([(-9, 3)]) == nil)
    }

    @Test("Long interval cadence never claims raw daily measurements")
    func sourceCadence() {
        #expect(MetricVisibleSummary.Basis.resolve(category: .hrv, period: .sixMonths) == .weeklyAverages)
        #expect(MetricVisibleSummary.Basis.resolve(category: .rhr, period: .year) == .monthlyAverages)
        #expect(MetricVisibleSummary.Basis.resolve(category: .heartRate, period: .day) == .hourlyAverages)
        #expect(MetricVisibleSummary.Basis.resolve(category: .steps, period: .year) == .monthlyTotals)
        #expect(MetricVisibleSummary.Basis.resolve(category: .sleep, period: .day) == .recordedSleepDays)
        #expect(MetricVisibleSummary.Basis.resolve(category: .exercise, period: .year) == .recordedWorkoutDays)
        #expect(MetricVisibleSummary.Basis.resolve(category: .weight, period: .year) == .measurements)
        #expect(MetricVisibleSummary.Basis.resolve(category: .breathingDisturbances, period: .month) == .nightlyRecords)
    }
}

private actor VisibleSummaryHRV: HRVQuerying {
    var rows: [(date: Date, average: Double)]
    init(rows: [(date: Date, average: Double)]) { self.rows = rows }
    func replace(_ rows: [(date: Date, average: Double)]) { self.rows = rows }
    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { [] }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] {
        rows.filter { $0.date >= start && $0.date < end }
    }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { [] }
}

private struct VisibleSummaryHistory: MetricHistoryQuerying {
    func earliestDate(for category: HealthMetric.Category) async throws -> Date? { nil }
    func latestDate(for category: HealthMetric.Category, before end: Date) async throws -> Date? { nil }
}

@Suite("MetricDetail visible source publication")
@MainActor
struct MetricDetailVisibleSummaryTests {
    @Test("History viewport and same-count source replacement update summary while legacy current-period summary stays fixed")
    func publication() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let oldDay = today.addingTimeInterval(-9 * 86400)
        let latestDay = today.addingTimeInterval(-2 * 86400)
        let service = VisibleSummaryHRV(rows: [(oldDay, 20), (latestDay, 80)])
        let vm = MetricDetailViewModel(hrvService: service, historyService: VisibleSummaryHistory())
        vm.configure(category: .hrv, currentValue: 80, lastUpdated: latestDay)
        await vm.loadData()
        #expect(vm.visibleSummary?.statistics.average == 80)
        let legacyAverage = vm.summaryStats?.average
        vm.scrollPosition = today.addingTimeInterval(-13 * 86400)
        await vm.loadData(historyNavigation: true)
        #expect(vm.visibleSummary?.statistics.average == 20)
        #expect(vm.summaryStats?.average == legacyAverage)
        await service.replace([(oldDay, 40), (latestDay, 80)])
        await vm.loadData(historyNavigation: true)
        #expect(vm.visibleSummary?.statistics.average == 40)
        #expect(vm.summaryStats?.average == legacyAverage)
        vm.configure(category: .wristTemperature, currentValue: -0.2, lastUpdated: nil)
        #expect(vm.visibleSummary == nil)
    }
}
