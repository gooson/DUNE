import Foundation
import Testing
@testable import DUNE

@MainActor
private protocol ScoreHistoryModel: AnyObject {
    var selectedPeriod: TimePeriod { get set }
    var scrollPosition: Date { get set }
    var showTrendLine: Bool { get set }
    var chartData: [ChartDataPoint] { get set }
    var hrvTrend: [ChartDataPoint] { get }
    var rhrTrend: [ChartDataPoint] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var trendLineData: [ChartDataPoint]? { get }
    func loadData() async
}

extension ConditionScoreDetailViewModel: ScoreHistoryModel {}
extension WellnessScoreDetailViewModel: ScoreHistoryModel {}
extension TrainingReadinessDetailViewModel: ScoreHistoryModel {}

private enum ScoreHistoryKind: CaseIterable {
    case condition, wellness, readiness

    @MainActor
    func makeModel(hrv: HRVQuerying = GatedScoreHRVService()) -> any ScoreHistoryModel {
        switch self {
        case .condition: ConditionScoreDetailViewModel(hrvService: hrv)
        case .wellness: WellnessScoreDetailViewModel(hrvService: hrv, sleepService: EmptyScoreSleepService())
        case .readiness: TrainingReadinessDetailViewModel(hrvService: hrv, sleepService: EmptyScoreSleepService())
        }
    }
}

/// Simulates HealthKit requests which finish even after their caller was cancelled.
private actor GatedScoreHRVService: HRVQuerying {
    private var fetchCount = 0
    private var pending: [Int: CheckedContinuation<[HRVSample], any Error>] = [:]
    private var started: [Int: CheckedContinuation<Void, Never>] = [:]
    let blockedFetches: Set<Int>

    init(blockedFetches: Set<Int> = [1]) { self.blockedFetches = blockedFetches }

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] {
        fetchCount += 1
        let index = fetchCount
        if blockedFetches.contains(index) {
            return try await withCheckedThrowingContinuation { continuation in
                pending[index] = continuation
                started.removeValue(forKey: index)?.resume()
            }
        }
        return samples(for: index)
    }

    func waitForFetch(_ index: Int) async {
        if pending[index] != nil { return }
        await withCheckedContinuation { started[index] = $0 }
    }

    func release(_ index: Int, fail: Bool = false) {
        let continuation = pending.removeValue(forKey: index)
        if fail {
            continuation?.resume(throwing: CocoaError(.fileReadUnknown))
        } else {
            continuation?.resume(returning: samples(for: index))
        }
    }

    private func samples(for index: Int) -> [HRVSample] {
        let date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-Double(index) * 86400)
        return [HRVSample(value: 40 + Double(index), date: date)]
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { [] }
}

private struct EmptyScoreSleepService: SleepQuerying {
    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { [] }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] { [] }
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
}

@Suite("Score detail history regressions")
@MainActor
struct ScoreDetailHistoryRegressionTests {
    @Test("Scrolling updates trend endpoints and clears an empty window", arguments: ScoreHistoryKind.allCases)
    fileprivate func scrollingUpdatesTrend(kind: ScoreHistoryKind) throws {
        let vm = kind.makeModel()
        let recentStart = TimePeriod.week.dateRange(offset: 0).start
        let oldStart = recentStart.addingTimeInterval(-14 * 86400)
        let recent = (0..<6).map { ChartDataPoint(date: recentStart.addingTimeInterval(Double($0) * 86400), value: 40 + Double($0)) }
        let old = (0..<6).map { ChartDataPoint(date: oldStart.addingTimeInterval(Double($0) * 86400), value: 80 - Double($0)) }
        vm.chartData = old + recent
        vm.scrollPosition = recentStart
        vm.showTrendLine = true
        #expect(vm.trendLineData?.first?.date == recent.first?.date)

        vm.scrollPosition = oldStart
        let trend = try #require(vm.trendLineData)
        #expect(trend.first?.date == old.first?.date)
        #expect(trend.last?.date == old.last?.date)
        #expect(try #require(trend.first).value > #require(trend.last).value)

        vm.scrollPosition = oldStart.addingTimeInterval(-30 * 86400)
        #expect(vm.trendLineData == nil)
        vm.scrollPosition = recentStart
        #expect(vm.trendLineData?.first?.date == recent.first?.date)
        vm.showTrendLine = false
        vm.scrollPosition = oldStart
        #expect(vm.trendLineData == nil)
    }

    @Test("Late response or error cannot replace a new day period", arguments: [ScoreHistoryKind.wellness, .readiness], [false, true])
    fileprivate func latePeriodResponseIsIgnored(kind: ScoreHistoryKind, fails: Bool) async {
        let service = GatedScoreHRVService()
        let vm = kind.makeModel(hrv: service)
        let oldLoad = Task { await vm.loadData() }
        await service.waitForFetch(1)

        vm.selectedPeriod = .day
        await vm.loadData()
        oldLoad.cancel()
        await service.release(1, fail: fails)
        await oldLoad.value

        #expect(vm.selectedPeriod == .day)
        #expect(vm.chartData.isEmpty)
        #expect(vm.hrvTrend.isEmpty)
        #expect(vm.rhrTrend.isEmpty)
        #expect(vm.errorMessage == nil)
        #expect(!vm.isLoading)
    }

    @Test("Superseded requests cannot clear a newer request's loading state", arguments: [ScoreHistoryKind.wellness, .readiness])
    fileprivate func staleLoadDoesNotFinishNewLoad(kind: ScoreHistoryKind) async {
        let service = GatedScoreHRVService(blockedFetches: [1, 2])
        let vm = kind.makeModel(hrv: service)
        let first = Task { await vm.loadData() }
        await service.waitForFetch(1)
        let second = Task { await vm.loadData() }
        await service.waitForFetch(2)

        await service.release(1)
        await first.value
        #expect(vm.isLoading)
        #expect(vm.chartData.isEmpty)

        await service.release(2)
        await second.value
        #expect(!vm.isLoading)
        #expect(vm.chartData.count == 1)
    }
}
