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

    @Test("loadData maps and sorts all trend series")
    func loadDataBuildsTrends() {
        let vm = TrainingReadinessDetailViewModel()

        let hrv: [DailySample] = [
            .init(date: day(-1), value: 48),
            .init(date: day(-3), value: 44),
            .init(date: day(-2), value: 46),
        ]
        let rhr: [DailySample] = [
            .init(date: day(-2), value: 58),
            .init(date: day(-1), value: 56),
        ]
        let sleep: [SleepDailySample] = [
            .init(date: day(-2), minutes: 420),
            .init(date: day(-1), minutes: 450),
        ]

        vm.loadData(readiness: makeReadiness(), hrvDailyAverages: hrv, rhrDailyData: rhr, sleepDailyData: sleep)

        #expect(vm.readiness != nil)
        #expect(vm.hrvTrend.count == 3)
        #expect(vm.rhrTrend.count == 2)
        #expect(vm.sleepTrend.count == 2)
        for index in 1..<vm.hrvTrend.count {
            #expect(vm.hrvTrend[index - 1].date <= vm.hrvTrend[index].date)
        }
        for index in 1..<vm.rhrTrend.count {
            #expect(vm.rhrTrend[index - 1].date <= vm.rhrTrend[index].date)
        }
        for index in 1..<vm.sleepTrend.count {
            #expect(vm.sleepTrend[index - 1].date <= vm.sleepTrend[index].date)
        }
        #expect(vm.isLoading == false)
    }

    @Test("Duplicate day inputs are deduplicated safely in readiness trend")
    func duplicateDaysHandled() {
        let vm = TrainingReadinessDetailViewModel()
        let targetDay = day(-1)

        let hrv: [DailySample] = [
            .init(date: targetDay, value: 40),
            .init(date: targetDay, value: 50), // duplicate day
        ]
        let rhr: [DailySample] = [
            .init(date: targetDay, value: 60),
            .init(date: targetDay, value: 58), // duplicate day
        ]
        let sleep: [SleepDailySample] = [
            .init(date: targetDay, minutes: 420),
            .init(date: targetDay, minutes: 480), // duplicate day
        ]

        vm.loadData(readiness: makeReadiness(score: 55), hrvDailyAverages: hrv, rhrDailyData: rhr, sleepDailyData: sleep)

        #expect(vm.readinessTrend.count == 1)
        #expect(vm.readinessTrend.first != nil)
        #expect(vm.readinessTrend.first!.value >= 0)
        #expect(vm.readinessTrend.first!.value <= 100)
    }

    @Test("No HRV data yields empty readiness trend")
    func noHrvNoReadinessTrend() {
        let vm = TrainingReadinessDetailViewModel()
        vm.loadData(readiness: nil, hrvDailyAverages: [], rhrDailyData: [], sleepDailyData: [])

        #expect(vm.readiness == nil)
        #expect(vm.readinessTrend.isEmpty)
        #expect(vm.hrvTrend.isEmpty)
        #expect(vm.rhrTrend.isEmpty)
        #expect(vm.sleepTrend.isEmpty)
    }
}
