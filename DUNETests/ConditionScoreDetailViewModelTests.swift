import Testing
import Foundation
@testable import DUNE

// MARK: - Mock HRV Service

private struct MockHRVService: HRVQuerying {
    var samples: [HRVSample] = []
    var rhrCollection: [(date: Date, min: Double, max: Double, average: Double)] = []

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { samples }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { rhrCollection }
}

// MARK: - Tests

@Suite("ConditionScoreDetailViewModel")
@MainActor
struct ConditionScoreDetailViewModelTests {

    private let calendar = Calendar.current

    /// Generates HRV samples spread across the given number of days.
    /// Each day gets samples with the specified average value.
    private func makeSamples(days: Int, baseValue: Double = 50.0, spread: Double = 5.0) -> [HRVSample] {
        let today = calendar.startOfDay(for: Date())
        var samples: [HRVSample] = []
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            // Add multiple samples per day for realistic data
            let value = baseValue + (dayOffset % 2 == 0 ? spread : -spread)
            samples.append(HRVSample(value: max(1, value), date: date))
            samples.append(HRVSample(value: max(1, value + 2), date: date.addingTimeInterval(3600)))
        }
        return samples
    }

    private func makeRHRCollection(days: Int, baseValue: Double = 60.0, spread: Double = 2.0) -> [(date: Date, min: Double, max: Double, average: Double)] {
        let today = calendar.startOfDay(for: Date())
        var samples: [(date: Date, min: Double, max: Double, average: Double)] = []
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let average = baseValue + (dayOffset % 2 == 0 ? spread : -spread)
            samples.append((date: date, min: average - 1, max: average + 1, average: average))
        }
        return samples
    }

    // MARK: - Loading

    @Test("loads chart data from HRV samples for week period")
    func loadsWeekData() async {
        let samples = makeSamples(days: 14, baseValue: 50, spread: 5)
        let service = MockHRVService(samples: samples, rhrCollection: makeRHRCollection(days: 14))
        let vm = ConditionScoreDetailViewModel(hrvService: service)
        let score = ConditionScore(score: 65, date: Date())
        vm.configure(score: score)

        await vm.loadData()

        #expect(!vm.chartData.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("chart data points have values in 0-100 range")
    func scoreValuesInRange() async {
        let samples = makeSamples(days: 14, baseValue: 50, spread: 5)
        let service = MockHRVService(samples: samples, rhrCollection: makeRHRCollection(days: 14))
        let vm = ConditionScoreDetailViewModel(hrvService: service)
        vm.configure(score: ConditionScore(score: 50, date: Date()))

        await vm.loadData()

        for point in vm.chartData {
            #expect(point.value >= 0 && point.value <= 100)
        }
    }

    // MARK: - Summary Stats

    @Test("summary stats are computed when data exists")
    func summaryComputed() async {
        let samples = makeSamples(days: 14, baseValue: 50, spread: 5)
        let service = MockHRVService(samples: samples, rhrCollection: makeRHRCollection(days: 14))
        let vm = ConditionScoreDetailViewModel(hrvService: service)
        vm.configure(score: ConditionScore(score: 55, date: Date()))

        await vm.loadData()

        #expect(vm.summaryStats != nil)
        if let stats = vm.summaryStats {
            #expect(stats.average >= 0 && stats.average <= 100)
            #expect(stats.min >= 0)
            #expect(stats.max <= 100)
        }
    }

    // MARK: - Empty Data

    @Test("empty samples produce no chart data")
    func emptyData() async {
        let service = MockHRVService(samples: [])
        let vm = ConditionScoreDetailViewModel(hrvService: service)
        vm.configure(score: ConditionScore(score: 0, date: Date()))

        await vm.loadData()

        #expect(vm.chartData.isEmpty)
        #expect(vm.summaryStats == nil)
        #expect(vm.highlights.isEmpty)
    }

    // MARK: - Insufficient Data

    @Test("fewer than 7 days produces no scores (baseline not ready)")
    func insufficientData() async {
        let samples = makeSamples(days: 3, baseValue: 50, spread: 5)
        let service = MockHRVService(samples: samples, rhrCollection: makeRHRCollection(days: 3))
        let vm = ConditionScoreDetailViewModel(hrvService: service)
        vm.configure(score: ConditionScore(score: 50, date: Date()))

        await vm.loadData()

        // With only 3 days, baseline is not ready so no scores computed
        #expect(vm.chartData.isEmpty)
    }

    // MARK: - Highlights

    @Test("highlights include high and low when sufficient data")
    func highlightsBuilt() async {
        let samples = makeSamples(days: 14, baseValue: 50, spread: 10)
        let service = MockHRVService(samples: samples, rhrCollection: makeRHRCollection(days: 14))
        let vm = ConditionScoreDetailViewModel(hrvService: service)
        vm.configure(score: ConditionScore(score: 60, date: Date()))

        await vm.loadData()

        // Should have at least high and low highlights if data exists
        if !vm.chartData.isEmpty {
            let types = Set(vm.highlights.map(\.type))
            #expect(types.contains(.high))
            #expect(types.contains(.low))
        }
    }

    // MARK: - Configure

    @Test("configure sets currentScore")
    func configureScore() {
        let vm = ConditionScoreDetailViewModel(hrvService: MockHRVService())
        let score = ConditionScore(score: 75, date: Date())
        vm.configure(score: score)

        #expect(vm.currentScore?.score == 75)
        #expect(vm.currentScore?.status == .good)
        #expect(vm.scrollPosition == TimePeriod.week.dateRange.start)
    }

    // MARK: - Loading State

    @Test("isLoading is false after load completes")
    func loadingState() async {
        let vm = ConditionScoreDetailViewModel(hrvService: MockHRVService())
        vm.configure(score: ConditionScore(score: 50, date: Date()))

        #expect(vm.isLoading == false)
        await vm.loadData()
        #expect(vm.isLoading == false)
    }

    @Test("scrollDomain extends beyond latest point so today remains reachable")
    func scrollDomainExtendsToToday() async {
        let service = MockHRVService(
            samples: makeSamples(days: 14, baseValue: 50, spread: 5),
            rhrCollection: makeRHRCollection(days: 14)
        )
        let vm = ConditionScoreDetailViewModel(hrvService: service)
        vm.configure(score: ConditionScore(score: 62, date: Date()))

        await vm.loadData()

        let currentRange = TimePeriod.week.dateRange
        let expectedUpperBound = TimePeriod.week.scrollDomainUpperBound(referenceDate: currentRange.end)
        #expect(vm.scrollDomain.upperBound == expectedUpperBound)

        if let latestPoint = vm.chartData.map(\.date).max() {
            #expect(vm.scrollDomain.upperBound > latestPoint)
        } else {
            Issue.record("Expected chart data for scrollDomain regression test")
        }
    }
}
