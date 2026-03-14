import Foundation
import Testing
@testable import DUNE

@Suite("TrainingReadinessDetailViewModel")
@MainActor
struct TrainingReadinessDetailViewModelTests {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func makeReadiness(score: Int = 70) -> TrainingReadiness {
        TrainingReadiness(
            score: score,
            components: .init(hrvScore: 70, rhrScore: 65, sleepScore: 75, fatigueScore: 68, trendBonus: 5)
        )
    }

    private func makeVM(
        hrvSamples: [HRVSample] = [],
        rhrCollection: [(date: Date, min: Double, max: Double, average: Double)] = [],
        sleepDurations: [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] = []
    ) -> TrainingReadinessDetailViewModel {
        let hrvService = MockHRVService(samples: hrvSamples, rhrCollection: rhrCollection)
        let sleepService = MockSleepService(dailySleep: sleepDurations)
        return TrainingReadinessDetailViewModel(hrvService: hrvService, sleepService: sleepService)
    }

    @Test("loadData populates trends from HealthKit services")
    func loadDataBuildsTrends() async {
        let vm = makeVM(
            hrvSamples: [
                HRVSample(value: 44, date: day(-3)),
                HRVSample(value: 46, date: day(-2)),
                HRVSample(value: 48, date: day(-1)),
            ],
            rhrCollection: [
                (date: day(-2), min: 55, max: 62, average: 58),
                (date: day(-1), min: 54, max: 60, average: 56),
            ],
            sleepDurations: [
                (date: day(-2), totalMinutes: 420, stageBreakdown: [:]),
                (date: day(-1), totalMinutes: 450, stageBreakdown: [:]),
            ]
        )

        vm.configure(readiness: makeReadiness())
        await vm.loadData()

        #expect(vm.readiness != nil)
        #expect(!vm.hrvTrend.isEmpty)
        #expect(!vm.rhrTrend.isEmpty)
        #expect(!vm.sleepTrend.isEmpty)
        #expect(!vm.chartData.isEmpty)
        #expect(vm.isLoading == false)

        // Verify sorted order
        for index in 1..<vm.hrvTrend.count {
            #expect(vm.hrvTrend[index - 1].date <= vm.hrvTrend[index].date)
        }
    }

    @Test("No HRV data yields empty chart data")
    func noHrvNoChartData() async {
        let vm = makeVM()
        vm.configure(readiness: nil)
        await vm.loadData()

        #expect(vm.readiness == nil)
        #expect(vm.chartData.isEmpty)
        #expect(vm.hrvTrend.isEmpty)
        #expect(vm.rhrTrend.isEmpty)
        #expect(vm.sleepTrend.isEmpty)
    }

    @Test("Summary stats are computed for current period")
    func summaryStatsComputed() async {
        let vm = makeVM(
            hrvSamples: (1...7).map { HRVSample(value: Double(40 + $0), date: day(-$0)) },
            rhrCollection: (1...7).map { (date: day(-$0), min: 55.0, max: 62.0, average: 58.0) },
            sleepDurations: (1...7).map { (date: day(-$0), totalMinutes: 420.0, stageBreakdown: [SleepStage.Stage: Double]()) }
        )

        vm.configure(readiness: makeReadiness())
        await vm.loadData()

        #expect(vm.summaryStats != nil)
        #expect(vm.summaryStats!.count > 0)
    }
}

// MARK: - Mock Services

private struct MockHRVService: HRVQuerying {
    let samples: [HRVSample]
    let rhrCollection: [(date: Date, min: Double, max: Double, average: Double)]

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { samples }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { rhrCollection }
}

private struct MockSleepService: SleepQuerying {
    let dailySleep: [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])]

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { [] }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] { dailySleep }
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
}
