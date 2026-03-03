import Foundation
import Testing
@testable import DUNE

private enum SleepViewModelTestError: Error {
    case failed
}

private struct MockSleepViewModelService: SleepQuerying {
    var sleepStagesByDay: [Date: [SleepStage]] = [:]
    var latestFallback: (stages: [SleepStage], date: Date)? = nil
    var shouldThrow = false

    private func dayKey(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] {
        if shouldThrow { throw SleepViewModelTestError.failed }
        return sleepStagesByDay[dayKey(for: date)] ?? []
    }

    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? {
        if shouldThrow { throw SleepViewModelTestError.failed }
        return latestFallback
    }

    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] {
        []
    }

    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
}

@Suite("SleepViewModel")
@MainActor
struct SleepViewModelTests {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func makeStage(_ stage: SleepStage.Stage, start: Date, minutes: Double) -> SleepStage {
        let duration = minutes * 60.0
        return SleepStage(
            stage: stage,
            duration: duration,
            startDate: start,
            endDate: start.addingTimeInterval(duration)
        )
    }

    @Test("Loads today sleep data and builds cached outputs")
    func loadsTodayData() async {
        let today = day(0)
        let stages = [
            makeStage(.deep, start: today, minutes: 120),
            makeStage(.core, start: today.addingTimeInterval(120 * 60), minutes: 300),
            makeStage(.rem, start: today.addingTimeInterval(420 * 60), minutes: 60),
            makeStage(.awake, start: today.addingTimeInterval(480 * 60), minutes: 20),
        ]

        var byDay: [Date: [SleepStage]] = [:]
        byDay[today] = stages
        let service = MockSleepViewModelService(sleepStagesByDay: byDay)
        let vm = SleepViewModel(sleepService: service)

        await vm.loadData()

        #expect(vm.todayStages.count == 4)
        #expect(vm.latestSleepDate != nil)
        #expect(vm.isShowingHistoricalData == false)
        #expect(abs(vm.totalSleepMinutes - 480) < 0.001)
        #expect(abs(vm.sleepEfficiency - 96) < 0.001)
        #expect(vm.sleepScore > 0)
        #expect(vm.weeklyData.count == 7)
        for index in 1..<vm.weeklyData.count {
            #expect(vm.weeklyData[index - 1].date <= vm.weeklyData[index].date)
        }
        #expect(vm.stageBreakdown.first?.stage == .deep)
        #expect(vm.stageBreakdown.first?.minutes == 120)
        #expect(vm.isLoading == false)
    }

    @Test("Falls back to latest sleep when today has no data")
    func latestFallbackUsed() async {
        let twoDaysAgo = day(-2)
        let fallbackStages = [
            makeStage(.core, start: twoDaysAgo, minutes: 240),
            makeStage(.rem, start: twoDaysAgo.addingTimeInterval(240 * 60), minutes: 80),
        ]

        let service = MockSleepViewModelService(
            sleepStagesByDay: [:],
            latestFallback: (stages: fallbackStages, date: twoDaysAgo)
        )
        let vm = SleepViewModel(sleepService: service)

        await vm.loadData()

        #expect(vm.todayStages.count == 2)
        #expect(vm.latestSleepDate != nil)
        #expect(calendar.isDate(vm.latestSleepDate!, inSameDayAs: twoDaysAgo))
        #expect(vm.isShowingHistoricalData)
        #expect(vm.sleepScore > 0)
        #expect(vm.errorMessage == nil)
    }

    @Test("No data produces zero score and no latest date")
    func noDataState() async {
        let service = MockSleepViewModelService(sleepStagesByDay: [:], latestFallback: nil)
        let vm = SleepViewModel(sleepService: service)

        await vm.loadData()

        #expect(vm.todayStages.isEmpty)
        #expect(vm.latestSleepDate == nil)
        #expect(vm.isShowingHistoricalData == false)
        #expect(vm.totalSleepMinutes == 0)
        #expect(vm.sleepScore == 0)
        #expect(vm.sleepEfficiency == 0)
        #expect(vm.weeklyData.count == 7)
    }

    @Test("Service error sets error message and clears loading")
    func serviceError() async {
        let service = MockSleepViewModelService(shouldThrow: true)
        let vm = SleepViewModel(sleepService: service)

        await vm.loadData()

        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }
}
