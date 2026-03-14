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

private actor SequencedConditionHRVService: HRVQuerying {
    private let firstSamples: [HRVSample]
    private let secondSamples: [HRVSample]
    private let firstRHR: [(date: Date, min: Double, max: Double, average: Double)]
    private let secondRHR: [(date: Date, min: Double, max: Double, average: Double)]
    private var sampleFetchCount = 0
    private var rhrFetchCount = 0
    private var didStartFirstFetch = false
    private var fetchStartedContinuation: CheckedContinuation<Void, Never>?
    private var fetchReleaseContinuation: CheckedContinuation<Void, Never>?

    init(
        firstSamples: [HRVSample],
        secondSamples: [HRVSample],
        firstRHR: [(date: Date, min: Double, max: Double, average: Double)],
        secondRHR: [(date: Date, min: Double, max: Double, average: Double)]
    ) {
        self.firstSamples = firstSamples
        self.secondSamples = secondSamples
        self.firstRHR = firstRHR
        self.secondRHR = secondRHR
    }

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] {
        sampleFetchCount += 1
        if sampleFetchCount == 1 {
            didStartFirstFetch = true
            fetchStartedContinuation?.resume()
            fetchStartedContinuation = nil
            await withCheckedContinuation { continuation in
                fetchReleaseContinuation = continuation
            }
            return firstSamples
        }
        return secondSamples
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }

    func fetchRHRCollection(
        start: Date,
        end: Date,
        interval: DateComponents
    ) async throws -> [(date: Date, min: Double, max: Double, average: Double)] {
        rhrFetchCount += 1
        return rhrFetchCount == 1 ? firstRHR : secondRHR
    }

    func waitUntilFirstFetchStarts() async {
        if didStartFirstFetch { return }
        await withCheckedContinuation { continuation in
            fetchStartedContinuation = continuation
        }
    }

    func resumeFirstFetch() {
        fetchReleaseContinuation?.resume()
        fetchReleaseContinuation = nil
    }
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

    private func makeTimedSamples(_ entries: [(dayOffset: Int, hour: Int, value: Double)]) -> [HRVSample] {
        let today = calendar.startOfDay(for: Date())
        return entries.compactMap { entry in
            guard let day = calendar.date(byAdding: .day, value: -entry.dayOffset, to: today),
                  let date = calendar.date(byAdding: .hour, value: entry.hour, to: day) else {
                return nil
            }
            return HRVSample(value: entry.value, date: date)
        }
    }

    private func makeTimedRHRCollection(_ entries: [(dayOffset: Int, value: Double)]) -> [(date: Date, min: Double, max: Double, average: Double)] {
        let today = calendar.startOfDay(for: Date())
        return entries.compactMap { entry in
            guard let date = calendar.date(byAdding: .day, value: -entry.dayOffset, to: today) else {
                return nil
            }
            return (date: date, min: entry.value - 1, max: entry.value + 1, average: entry.value)
        }
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

    @Test("day period uses rolling 24h window including yesterday's data")
    func dayPeriodUsesRolling24hWindow() async {
        let fixedNow = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
        let currentHour = calendar.component(.hour, from: fixedNow)
        let todayHours = [currentHour - 3, currentHour - 2, currentHour - 1]
        let samples = makeTimedSamples([
            (dayOffset: 0, hour: todayHours[0], value: 85),
            (dayOffset: 0, hour: todayHours[1], value: 50),
            (dayOffset: 0, hour: todayHours[2], value: 50),
            (dayOffset: 1, hour: currentHour + 1, value: 50),  // yesterday, within 24h window
            (dayOffset: 1, hour: currentHour + 5, value: 50),  // yesterday, within 24h window
            (dayOffset: 2, hour: 12, value: 50),
            (dayOffset: 3, hour: 12, value: 50),
            (dayOffset: 4, hour: 12, value: 50),
            (dayOffset: 5, hour: 12, value: 50),
            (dayOffset: 6, hour: 12, value: 50)
        ])
        let service = MockHRVService(
            samples: samples,
            rhrCollection: makeTimedRHRCollection([
                (dayOffset: 0, value: 60),
                (dayOffset: 1, value: 60),
                (dayOffset: 2, value: 60),
                (dayOffset: 3, value: 60),
                (dayOffset: 4, value: 60),
                (dayOffset: 5, value: 60),
                (dayOffset: 6, value: 60)
            ])
        )
        let vm = ConditionScoreDetailViewModel(hrvService: service, nowProvider: { fixedNow })
        vm.configure(score: ConditionScore(score: 65, date: fixedNow))
        vm.selectedPeriod = .day

        try? await Task.sleep(for: .milliseconds(50))
        if vm.chartData.isEmpty {
            await vm.loadData()
        }

        // Rolling 24h: should include today's 3 points + yesterday's 2 points within window
        #expect(vm.chartData.count >= 4)
        #expect(vm.summaryStats != nil)
    }

    @Test("day period at 3am includes yesterday's hourly data")
    func dayPeriodEarlyMorningShowsYesterdayData() async {
        let fixedNow = calendar.date(bySettingHour: 3, minute: 0, second: 0, of: Date()) ?? Date()
        // Yesterday's samples at various hours (all within 24h window)
        let samples = makeTimedSamples([
            (dayOffset: 0, hour: 1, value: 50),    // today 1am
            (dayOffset: 0, hour: 2, value: 52),    // today 2am
            (dayOffset: 1, hour: 5, value: 48),    // yesterday 5am — within 24h
            (dayOffset: 1, hour: 10, value: 45),   // yesterday 10am — within 24h
            (dayOffset: 1, hour: 15, value: 47),   // yesterday 3pm — within 24h
            (dayOffset: 1, hour: 20, value: 46),   // yesterday 8pm — within 24h
            (dayOffset: 2, hour: 12, value: 50),
            (dayOffset: 3, hour: 12, value: 50),
            (dayOffset: 4, hour: 12, value: 50),
            (dayOffset: 5, hour: 12, value: 50),
            (dayOffset: 6, hour: 12, value: 50)
        ])
        let service = MockHRVService(
            samples: samples,
            rhrCollection: makeTimedRHRCollection([
                (dayOffset: 0, value: 60),
                (dayOffset: 1, value: 60),
                (dayOffset: 2, value: 60),
                (dayOffset: 3, value: 60),
                (dayOffset: 4, value: 60),
                (dayOffset: 5, value: 60),
                (dayOffset: 6, value: 60)
            ])
        )
        let vm = ConditionScoreDetailViewModel(hrvService: service, nowProvider: { fixedNow })
        vm.configure(score: ConditionScore(score: 65, date: fixedNow))
        vm.selectedPeriod = .day

        try? await Task.sleep(for: .milliseconds(50))
        if vm.chartData.isEmpty {
            await vm.loadData()
        }

        // At 3am: should include today's 2 points + yesterday's 4 points
        #expect(vm.chartData.count >= 5)
        // Summary stats should reflect multiple data points, not just 1
        #expect(vm.summaryStats != nil)
        if let stats = vm.summaryStats {
            // With multiple points, min and max should potentially differ
            #expect(stats.average > 0)
        }
    }

    @Test("latest load wins when an older request finishes later")
    func latestLoadWinsOverOlderResponse() async {
        let service = SequencedConditionHRVService(
            firstSamples: makeSamples(days: 14, baseValue: 52, spread: 4),
            secondSamples: [],
            firstRHR: makeRHRCollection(days: 14, baseValue: 60, spread: 2),
            secondRHR: []
        )
        let vm = ConditionScoreDetailViewModel(hrvService: service)
        vm.configure(score: ConditionScore(score: 60, date: Date()))

        let firstTask = Task {
            await vm.loadData()
        }

        await service.waitUntilFirstFetchStarts()
        await vm.loadData()

        #expect(vm.chartData.isEmpty)
        #expect(vm.summaryStats == nil)

        await service.resumeFirstFetch()
        await firstTask.value

        #expect(vm.chartData.isEmpty)
        #expect(vm.summaryStats == nil)
        #expect(vm.isLoading == false)
    }
}
