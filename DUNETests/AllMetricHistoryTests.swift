import Foundation
import Testing
@testable import DUNE

private struct HistoryBreathingService: BreathingDisturbanceQuerying {
    let dates: [Date]
    func fetchNightlyDisturbances(days: Int) async throws -> [BreathingDisturbanceSample] {
        dates.map { BreathingDisturbanceSample(value: 5, date: $0, isElevated: false) }
    }
    func fetchLatestDisturbance(withinDays days: Int) async throws -> BreathingDisturbanceSample? { nil }
    func analyze(samples: [BreathingDisturbanceSample]) -> BreathingDisturbanceAnalysis {
        BreathingDisturbanceQueryService().analyze(samples: samples)
    }
}

@Suite("All metric history contract")
@MainActor
struct AllMetricHistoryTests {
    private let dates = [Calendar.current.startOfDay(for: Date()), Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_293_840_000))]
    private var hrv: MockAllDataHRVService {
        MockAllDataHRVService(hrvSamples: dates.map { HRVSample(value: 50, date: $0) }, rhrByDay: Dictionary(uniqueKeysWithValues: dates.map { ($0, 60) }))
    }
    private var sleep: MockAllDataSleepService {
        MockAllDataSleepService(stagesByDay: Dictionary(uniqueKeysWithValues: dates.map {
            ($0, [SleepStage(stage: .core, duration: 3600, startDate: $0, endDate: $0.addingTimeInterval(3600))])
        }))
    }
    private var steps: MockAllDataStepsService { MockAllDataStepsService(stepsByDay: Dictionary(uniqueKeysWithValues: dates.map { ($0, 1000) })) }
    private var workouts: MockAllDataWorkoutService {
        MockAllDataWorkoutService(workouts: dates.map { WorkoutSummary(id: $0.description, type: "Running", duration: 1800, calories: 100, distance: nil, date: $0) })
    }
    private var body: MockAllDataBodyService {
        let values = dates.map { BodyCompositionSample(value: 50, date: $0) }
        return MockAllDataBodyService(weight: values, bmi: values, fat: values, lean: values)
    }
    private var heart: MockAllDataHeartRateService { MockAllDataHeartRateService(history: dates.map { VitalSample(value: 60, date: $0) }) }
    private var vitals: MockAllDataVitalsService {
        let values = dates.map { VitalSample(value: 50, date: $0) }
        return MockAllDataVitalsService(spo2: values, respiratory: values, vo2Max: values, recovery: values, wristTemp: values)
    }

    @Test("Every metric crosses empty years without duplicates and terminates", arguments: HealthMetric.Category.allCases)
    func listHistory(category: HealthMetric.Category) async {
        let vm = AllDataViewModel(hrvService: hrv, sleepService: sleep, stepsService: steps, workoutService: workouts, bodyService: body, heartRateService: heart, vitalsService: vitals, breathingDisturbanceService: HistoryBreathingService(dates: dates), historyService: HistoryDates(dates: dates))
        vm.configure(category: category)
        await vm.loadInitialData()
        for _ in 0..<4 where vm.hasMoreData { await vm.loadNextPage() }
        #expect(vm.dataPoints.map(\.date) == dates)
        #expect(!vm.hasMoreData)
    }

    @Test("Every chart can load 2011 without retaining intervening years", arguments: HealthMetric.Category.allCases)
    func chartHistory(category: HealthMetric.Category) async {
        let vm = MetricDetailViewModel(hrvService: hrv, sleepService: sleep, stepsService: steps, workoutService: workouts, bodyService: body, heartRateService: heart, vitalsService: vitals, breathingDisturbanceService: HistoryBreathingService(dates: dates), historyService: HistoryDates(dates: dates))
        vm.configure(category: category, currentValue: 50, lastUpdated: dates[0])
        await vm.loadData()
        #expect(vm.scrollDomain.lowerBound <= dates[1])
        vm.scrollPosition = dates[1]
        await vm.loadVisibleHistoryIfNeeded()
        #expect(vm.chartData.contains { $0.date == dates[1] && $0.value > 0 })
        #expect(vm.chartData.count < 100)
        #expect(vm.chartData.allSatisfy { abs($0.date.timeIntervalSince(dates[1])) < 40 * 86400 })
        #expect(vm.scrollDomain.lowerBound <= dates[1])
        // Empty middle years must leave the domain scrollable.
        vm.scrollPosition = dates[1].addingTimeInterval(365 * 86400)
        await vm.loadVisibleHistoryIfNeeded()
        #expect(vm.earliestHistoryDate == dates[1])
        #expect(vm.scrollDomain.lowerBound <= dates[1])
    }
}
