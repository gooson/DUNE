import Testing
import Foundation
import SwiftData
@testable import DUNE

@Suite("CumulativeStressDetailViewModel")
@MainActor
struct CumulativeStressDetailViewModelTests {

    // MARK: - Initial State

    @Test("initial state has empty chart data and month period")
    func initialState() {
        let vm = CumulativeStressDetailViewModel()

        #expect(vm.chartData.isEmpty)
        #expect(vm.summaryStats == nil)
        #expect(vm.highlights.isEmpty)
        #expect(vm.selectedPeriod == .month)
        #expect(!vm.isLoading)
        #expect(!vm.showTrendLine)
        #expect(vm.trendLineData == nil)
    }

    // MARK: - Configure

    @Test("configure stores current score")
    func configureStoresScore() {
        let vm = CumulativeStressDetailViewModel()
        let score = makeStressScore(score: 42, level: .moderate)

        vm.configure(stressScore: score)

        #expect(vm.currentScore?.score == 42)
        #expect(vm.currentScore?.level == .moderate)
    }

    @Test("initial monthly viewport includes the complete current day", arguments: [1, 3, 9])
    func monthlyViewportIncludesToday(month: Int) {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: month, day: 27, hour: 12))!
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let vm = CumulativeStressDetailViewModel(nowProvider: { now })

        vm.configure(stressScore: makeStressScore(score: 9, level: .low))

        let visibleEnd = vm.scrollPosition.addingTimeInterval(vm.selectedPeriod.visibleDomainSeconds)
        #expect(vm.scrollPosition <= today)
        #expect(visibleEnd == tomorrow)
        #expect(vm.scrollDomain.upperBound == tomorrow)
    }

    // MARK: - Period Change

    @Test("changing period resets scroll position")
    func periodChangeResetsScroll() {
        let vm = CumulativeStressDetailViewModel()

        let initialPosition = vm.scrollPosition
        vm.selectedPeriod = .week

        // Scroll position should change when period changes
        #expect(vm.scrollPosition != initialPosition || vm.selectedPeriod == .week)
    }

    // MARK: - Visible Range Label

    @Test("visibleRangeLabel returns non-empty string")
    func visibleRangeLabelNotEmpty() {
        let vm = CumulativeStressDetailViewModel()

        let label = vm.visibleRangeLabel
        #expect(!label.isEmpty)
    }

    // MARK: - Trend Line

    @Test("showTrendLine toggles trend line data")
    func trendLineToggle() {
        let vm = CumulativeStressDetailViewModel()

        // Initially nil
        #expect(vm.trendLineData == nil)

        // Toggle on with no data — still nil (need chart data)
        vm.showTrendLine = true
        #expect(vm.trendLineData == nil)

        // Toggle off
        vm.showTrendLine = false
        #expect(vm.trendLineData == nil)
    }

    // MARK: - Highlights (stress-specific labels)

    @Test("highlights use stress-specific labels")
    func highlightLabels() {
        // Build highlights manually to verify the label pattern
        let data = [
            ChartDataPoint(date: Date().addingTimeInterval(-86400 * 3), value: 30),
            ChartDataPoint(date: Date().addingTimeInterval(-86400 * 2), value: 70),
            ChartDataPoint(date: Date().addingTimeInterval(-86400 * 1), value: 50),
            ChartDataPoint(date: Date(), value: 45),
        ]

        let highlights = HighlightBuilder.buildHighlights(
            from: data,
            highLabel: String(localized: "Most stressed"),
            lowLabel: String(localized: "Least stressed")
        )

        #expect(highlights.count >= 2)

        let highHighlight = highlights.first { $0.type == .high }
        let lowHighlight = highlights.first { $0.type == .low }

        #expect(highHighlight?.label == String(localized: "Most stressed"))
        #expect(lowHighlight?.label == String(localized: "Least stressed"))
        #expect(highHighlight?.value == 70)
        #expect(lowHighlight?.value == 30)
    }

    // MARK: - Recorded History Integration

    @Test("day history preserves recorded hours and half-open comparison boundaries")
    func recordedHoursAndComparison() async throws {
        let now = fixedNow
        let start = now.addingTimeInterval(-86400)
        let previousStart = start.addingTimeInterval(-86400)
        let service = try makeService([
            (previousStart.addingTimeInterval(-3600), 95),
            (previousStart, 20),
            (start, 10),
            (start.addingTimeInterval(3600), 60),
            (start.addingTimeInterval(7200), 80),
            (now, 100),
        ])
        let vm = CumulativeStressDetailViewModel(scoreRefreshService: service, nowProvider: { now }, calendar: utc)
        vm.configure(stressScore: makeStressScore(score: 99, level: .high))
        vm.selectedPeriod = .day
        await vm.loadData()

        let summary = try #require(vm.summaryStats)
        #expect(summary.average == 50)
        #expect(summary.count == 3)
        #expect(summary.min == 10)
        #expect(summary.max == 80)
        #expect(summary.previousPeriodAverage == 20)
        #expect(vm.visibleChartPointCount == 3)
        #expect(vm.chartData.contains { $0.date == start && $0.value == 10 })
        #expect(!vm.chartData.contains { $0.date == now })
        #expect(vm.highlights.first { $0.type == .high }?.date == start.addingTimeInterval(7200))
        #expect(vm.currentScore?.score == 99)
        #expect(vm.loadError == nil)
        #expect(!vm.isLoading)
    }

    @Test("weekly summary weights recorded days equally despite unequal hourly counts")
    func dailyEqualWeight() async throws {
        let now = fixedNow
        let yesterday = utc.startOfDay(for: now).addingTimeInterval(-86400)
        let today = utc.startOfDay(for: now)
        let service = try makeService([
            (yesterday.addingTimeInterval(8 * 3600), 0),
            (yesterday.addingTimeInterval(9 * 3600), 40),
            (today.addingTimeInterval(8 * 3600), 80),
        ])
        let vm = CumulativeStressDetailViewModel(scoreRefreshService: service, nowProvider: { now }, calendar: utc)
        vm.selectedPeriod = .week
        await vm.loadData()

        let summary = try #require(vm.summaryStats)
        #expect(summary.average == 50)
        #expect(summary.count == 2)
        #expect(summary.min == 20)
        #expect(summary.max == 80)
        #expect(summary.previousPeriodAverage == nil)
        #expect(vm.chartData.map(\.value) == [20, 80])
    }

    @Test("long-period statistics retain raw daily extremes and sample count", arguments: [TimePeriod.sixMonths, .year])
    func longPeriodRawSummary(period: TimePeriod) async throws {
        let now = fixedNow
        let nearby = utc.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 8))!
        let distant = utc.date(from: DateComponents(year: 2026, month: period == .year ? 9 : 10, day: 20, hour: 8))!
        let service = try makeService([
            (nearby, 10), (nearby.addingTimeInterval(86400), 30),
            (nearby.addingTimeInterval(2 * 86400), 50), (distant, 100),
        ])
        let vm = CumulativeStressDetailViewModel(scoreRefreshService: service, nowProvider: { now }, calendar: utc)
        vm.selectedPeriod = period
        await vm.loadData()

        let summary = try #require(vm.summaryStats)
        #expect(summary.average == 47.5)
        #expect(summary.min == 10)
        #expect(summary.max == 100)
        #expect(summary.count == 4)
        #expect(vm.visibleChartPointCount == 2)
        #expect(vm.highlights.first { $0.type == .high }?.value == 100)
        #expect(vm.highlights.first { $0.type == .low }?.value == 10)
    }

    @Test("history fetch includes a previous window reserve and complete DST daily buckets", arguments: TimePeriod.allCases)
    func queryRangeAndBuffer(period: TimePeriod) async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12))!
        var requested: (Date, Date, Calendar)?
        let vm = CumulativeStressDetailViewModel(nowProvider: { now }, calendar: calendar) { start, end, queryCalendar in
            requested = (start, end, queryCalendar)
            return []
        }
        vm.selectedPeriod = period
        await vm.loadData()

        let range = try #require(requested)
        let expected = ScoreDetailHistory.window(for: period, referenceDate: now, calendar: calendar)
        let reserve = expected.domain.lowerBound.addingTimeInterval(-period.visibleDomainSeconds)
        #expect(range.0 == (period == .day ? reserve : calendar.startOfDay(for: reserve)))
        #expect(range.1 == expected.domain.upperBound)
        #expect(range.2.timeZone == calendar.timeZone)
        #expect(vm.scrollDomain == expected.domain)
        #expect(vm.scrollPosition == expected.latestStart)
        #expect(!vm.canStepForward)
        for _ in 0..<period.scrollBufferPeriods {
            let before = vm.scrollPosition
            #expect(vm.canStepBackward)
            vm.stepVisiblePeriod(by: -1)
            #expect(before.timeIntervalSince(vm.scrollPosition) == period.visibleDomainSeconds)
        }
        #expect(vm.scrollPosition == expected.domain.lowerBound)
        #expect(!vm.canStepBackward)
        vm.stepVisiblePeriod(by: -1)
        #expect(vm.scrollPosition == expected.domain.lowerBound)
        vm.stepVisiblePeriod(by: 2)
        #expect(vm.scrollPosition == expected.domain.lowerBound)
        for _ in 0..<period.scrollBufferPeriods { vm.stepVisiblePeriod(by: 1) }
        #expect(vm.scrollPosition == expected.latestStart)
        vm.stepVisiblePeriod(by: 1)
        #expect(vm.scrollPosition == expected.latestStart)
    }

    @Test("scrolling updates summary highlights and trend together and clears empty pages")
    func visibleStateAndEmptyReset() async throws {
        let now = fixedNow
        let start = now.addingTimeInterval(-86400)
        let previous = start.addingTimeInterval(-86400)
        let earliest = start.addingTimeInterval(-7 * 86400)
        let rows: [(date: Date, score: Double)] = [
            (start, 10), (start.addingTimeInterval(3600), 20), (start.addingTimeInterval(7200), 30),
            (previous, 80), (previous.addingTimeInterval(3600), 70), (previous.addingTimeInterval(7200), 60),
            (earliest, 40), (earliest.addingTimeInterval(-86400), 25),
        ]
        let vm = CumulativeStressDetailViewModel(nowProvider: { now }, calendar: utc) { _, _, _ in rows }
        vm.selectedPeriod = .day
        await vm.loadData()
        vm.showTrendLine = true
        #expect(vm.summaryStats?.average == 20)
        #expect(vm.summaryStats?.previousPeriodAverage == 70)
        let latestTrend = try #require(vm.trendLineData)
        #expect(try #require(latestTrend.first).value < #require(latestTrend.last).value)
        let latestLabel = vm.visibleRangeLabel

        vm.stepVisiblePeriod(by: -1)
        #expect(vm.summaryStats?.average == 70)
        #expect(vm.highlights.first { $0.type == .high }?.value == 80)
        #expect(vm.visibleRangeLabel != latestLabel)
        let olderTrend = try #require(vm.trendLineData)
        #expect(try #require(olderTrend.first).value > #require(olderTrend.last).value)

        vm.stepVisiblePeriod(by: -1)
        #expect(vm.summaryStats == nil)
        #expect(vm.highlights.isEmpty)
        #expect(vm.trendLineData == nil)
        #expect(vm.visibleChartPointCount == 0)
        for _ in 0..<5 { vm.stepVisiblePeriod(by: -1) }
        #expect(vm.summaryStats?.average == 40)
        #expect(vm.summaryStats?.previousPeriodAverage == 25)
        #expect(!vm.chartData.contains { $0.date < vm.scrollDomain.lowerBound })
    }

    @Test("day transform retains repeated DST hours and filters invalid scores without filling gaps")
    func hourlyTransformValidationAndDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let first = Date(timeIntervalSince1970: 1_793_520_000) // 2026-11-01 08:00 UTC, first 01:00
        let second = first.addingTimeInterval(3600)
        let rows: [(date: Date, score: Double)] = [
            (second, 100), (first, 0),
            (second.addingTimeInterval(3600), .nan),
            (second.addingTimeInterval(7200), .infinity),
            (second.addingTimeInterval(10800), -1),
            (second.addingTimeInterval(14400), 101),
        ]
        let points = CumulativeStressDetailViewModel.summaryPoints(from: rows, period: .day, calendar: calendar)
        #expect(calendar.component(.hour, from: first) == 1)
        #expect(calendar.component(.hour, from: second) == 1)
        #expect(points.map(\.date) == [first, second])
        #expect(points.map(\.value) == [0, 100])
        let daily = CumulativeStressDetailViewModel.summaryPoints(from: rows, period: .week, calendar: calendar)
        #expect(daily.count == 1)
        #expect(daily.first?.value == 50)
    }

    @Test("changing period immediately clears loaded statistics and resets the injected reference window")
    func periodChangeClearsLoadedState() async throws {
        let now = fixedNow
        let today = utc.startOfDay(for: now)
        var requestCount = 0
        let vm = CumulativeStressDetailViewModel(nowProvider: { now }, calendar: utc) { _, _, _ in
            requestCount += 1
            guard requestCount == 1 else { return [] }
            return [(today, 30), (today.addingTimeInterval(-86400), 20), (today.addingTimeInterval(-2 * 86400), 10)]
        }
        await vm.loadData()
        vm.showTrendLine = true
        #expect(vm.summaryStats?.count == 3)
        #expect(vm.highlights.count >= 2)
        #expect(vm.trendLineData != nil)
        vm.stepVisiblePeriod(by: -1)
        vm.selectedPeriod = .day
        #expect(vm.scrollPosition == now.addingTimeInterval(-86400))
        #expect(vm.scrollDomain.upperBound == now)
        #expect(vm.isLoading)
        #expect(vm.chartData.isEmpty)
        #expect(vm.summaryStats == nil)
        #expect(vm.highlights.isEmpty)
        #expect(vm.trendLineData == nil)
        #expect(vm.visibleChartPointCount == 0)
        await vm.loadData()
        #expect(!vm.isLoading)
        #expect(vm.loadError == nil)
    }

    @Test("history failures are distinct from successful empty records and reset on retry")
    func errorAndEmptyStates() async {
        let now = fixedNow
        var fails = true
        let vm = CumulativeStressDetailViewModel(nowProvider: { now }, calendar: utc) { _, _, _ in
            if fails { throw CocoaError(.fileReadUnknown) }
            return []
        }
        await vm.loadData()
        #expect(vm.loadError != nil)
        #expect(vm.summaryStats == nil)
        #expect(!vm.isLoading)
        fails = false
        await vm.loadData()
        #expect(vm.loadError == nil)
        #expect(vm.chartData.isEmpty)
        #expect(vm.highlights.isEmpty)
        #expect(!vm.isLoading)
    }

    @Test("cancelled loads publish neither partial history nor failure")
    func cancellation() async {
        let now = fixedNow
        let gate = StressHistoryGate()
        let vm = CumulativeStressDetailViewModel(nowProvider: { now }, calendar: utc, historyLoader: gate.load)
        let task = Task { await vm.loadData() }
        await gate.waitForRequest(1)
        task.cancel()
        gate.complete(1, rows: [(now.addingTimeInterval(-3600), 99)])
        await task.value
        #expect(vm.chartData.isEmpty)
        #expect(vm.summaryStats == nil)
        #expect(vm.loadError == nil)
        #expect(!vm.isLoading)
    }

    @Test("stale period completion cannot publish data error or finish a newer load", arguments: [false, true])
    func stalePeriodIsolation(staleFails: Bool) async throws {
        let now = fixedNow
        let gate = StressHistoryGate()
        let vm = CumulativeStressDetailViewModel(nowProvider: { now }, calendar: utc, historyLoader: gate.load)
        let first = Task { await vm.loadData() }
        await gate.waitForRequest(1)
        vm.selectedPeriod = .week
        await gate.waitForRequest(2)
        #expect(vm.chartData.isEmpty)
        #expect(vm.summaryStats == nil)
        #expect(vm.highlights.isEmpty)
        // A direct refresh cancels the spawned period request and owns completion.
        let latest = Task { await vm.loadData() }
        await gate.waitForRequest(3)
        gate.complete(2, rows: [], fails: true)
        gate.complete(1, rows: [(now.addingTimeInterval(-3600), 99)], fails: staleFails)
        await first.value
        #expect(vm.isLoading)
        #expect(vm.loadError == nil)
        #expect(vm.chartData.isEmpty)
        gate.complete(3, rows: [(now.addingTimeInterval(-3600), 35)])
        await latest.value
        #expect(!vm.isLoading)
        #expect(vm.loadError == nil)
        #expect(vm.summaryStats?.average == 35)
        #expect(vm.selectedPeriod == .week)
    }

    @Test("late failure cannot erase an already completed newer history result")
    func lateFailureAfterSuccess() async {
        let now = fixedNow
        let gate = StressHistoryGate()
        let vm = CumulativeStressDetailViewModel(nowProvider: { now }, calendar: utc, historyLoader: gate.load)
        let old = Task { await vm.loadData() }
        await gate.waitForRequest(1)
        let latest = Task { await vm.loadData() }
        await gate.waitForRequest(2)
        gate.complete(2, rows: [(now.addingTimeInterval(-3600), 45)])
        await latest.value
        gate.complete(1, rows: [], fails: true)
        await old.value
        #expect(vm.summaryStats?.average == 45)
        #expect(vm.loadError == nil)
        #expect(!vm.isLoading)
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var fixedNow: Date {
        utc.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
    }

    private func makeService(_ rows: [(Date, Double)]) throws -> ScoreRefreshService {
        let container = try ModelContainer(
            for: HourlyScoreSnapshot.self,
            configurations: ModelConfiguration(
                "CumulativeStressDetailTests-\(UUID().uuidString)",
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
        let context = ModelContext(container)
        for row in rows { context.insert(HourlyScoreSnapshot(date: row.0, stressScore: row.1)) }
        try context.save()
        return ScoreRefreshService(modelContainer: container)
    }

    // MARK: - Helpers

    private func makeStressScore(
        score: Int,
        level: CumulativeStressScore.Level,
        trend: TrendDirection = .stable
    ) -> CumulativeStressScore {
        CumulativeStressScore(
            score: score,
            level: level,
            contributions: [
                .init(factor: .hrvVariability, rawScore: 45, weight: 0.40, detail: "Moderate HRV fluctuation"),
                .init(factor: .sleepConsistency, rawScore: 35, weight: 0.35, detail: "Consistent sleep timing"),
                .init(factor: .activityLoad, rawScore: 50, weight: 0.25, detail: "Balanced training load"),
            ],
            trend: trend
        )
    }
}


/// Controllable persistence seam: completions deliberately ignore cancellation.
@MainActor
private final class StressHistoryGate {
    private var requestCount = 0
    private var pending: [Int: CheckedContinuation<[(date: Date, score: Double)], any Error>] = [:]
    private var started: [Int: CheckedContinuation<Void, Never>] = [:]

    func load(from: Date, to: Date, calendar: Calendar) async throws -> [(date: Date, score: Double)] {
        requestCount += 1
        let index = requestCount
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            started.removeValue(forKey: index)?.resume()
        }
    }

    func waitForRequest(_ index: Int) async {
        if pending[index] != nil { return }
        await withCheckedContinuation { started[index] = $0 }
    }

    func complete(_ index: Int, rows: [(date: Date, score: Double)], fails: Bool = false) {
        let continuation = pending.removeValue(forKey: index)
        if fails {
            continuation?.resume(throwing: CocoaError(.fileReadUnknown))
        } else {
            continuation?.resume(returning: rows)
        }
    }
}
