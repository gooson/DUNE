import Foundation
import Testing
@testable import DUNE

private struct MockAllDataHRVService: HRVQuerying {
    var hrvSamples: [HRVSample] = []
    var rhrByDay: [Date: Double] = [:]

    private func key(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { hrvSamples }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { rhrByDay[key(date)] }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { [] }
}

private struct MockAllDataSleepService: SleepQuerying {
    var stagesByDay: [Date: [SleepStage]] = [:]

    private func key(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { stagesByDay[key(date)] ?? [] }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] { [] }
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
}

private struct MockAllDataStepsService: StepsQuerying {
    var stepsByDay: [Date: Double] = [:]

    private func key(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    func fetchSteps(for date: Date) async throws -> Double? { stepsByDay[key(date)] }
    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)] { [] }
}

private struct MockAllDataWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { workouts }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] { workouts }
}

private struct MockAllDataBodyService: BodyCompositionQuerying {
    var weight: [BodyCompositionSample] = []
    var bmi: [BodyCompositionSample] = []
    var fat: [BodyCompositionSample] = []
    var lean: [BodyCompositionSample] = []

    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] { weight }
    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] { fat }
    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] { lean }
    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] { weight }
    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchBMI(for date: Date) async throws -> Double? { nil }
    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] { bmi }
    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
}

private struct MockAllDataHeartRateService: HeartRateQuerying {
    var history: [VitalSample] = []

    func fetchHeartRateSamples(forWorkoutID workoutID: String) async throws -> [HeartRateSample] { [] }
    func fetchHeartRateSummary(forWorkoutID workoutID: String) async throws -> HeartRateSummary {
        HeartRateSummary(average: 0, max: 0, min: 0, samples: [])
    }
    func fetchLatestHeartRate(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchHeartRateHistory(days: Int) async throws -> [VitalSample] { history }
    func fetchHeartRateHistory(start: Date, end: Date) async throws -> [VitalSample] { history }
    func fetchHeartRateZones(forWorkoutID workoutID: String, maxHR: Double) async throws -> [HeartRateZone] { [] }
    func fetchHeartRateRecovery(forWorkoutID workoutID: String) async throws -> HeartRateRecovery? { nil }
}

private struct MockAllDataVitalsService: VitalsQuerying {
    var spo2: [VitalSample] = []
    var respiratory: [VitalSample] = []
    var vo2Max: [VitalSample] = []
    var recovery: [VitalSample] = []
    var wristTemp: [VitalSample] = []

    func fetchLatestSpO2(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestRespiratoryRate(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestVO2Max(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestHeartRateRecovery(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestWristTemperature(withinDays days: Int) async throws -> VitalSample? { nil }

    func fetchSpO2Collection(days: Int) async throws -> [VitalSample] { spo2 }
    func fetchRespiratoryRateCollection(days: Int) async throws -> [VitalSample] { respiratory }
    func fetchVO2MaxHistory(days: Int) async throws -> [VitalSample] { vo2Max }
    func fetchHeartRateRecoveryHistory(days: Int) async throws -> [VitalSample] { recovery }
    func fetchWristTemperatureCollection(days: Int) async throws -> [VitalSample] { wristTemp }

    func fetchSpO2Collection(start: Date, end: Date) async throws -> [VitalSample] { spo2 }
    func fetchRespiratoryRateCollection(start: Date, end: Date) async throws -> [VitalSample] { respiratory }
    func fetchVO2MaxHistory(start: Date, end: Date) async throws -> [VitalSample] { vo2Max }
    func fetchHeartRateRecoveryHistory(start: Date, end: Date) async throws -> [VitalSample] { recovery }
    func fetchWristTemperatureCollection(start: Date, end: Date) async throws -> [VitalSample] { wristTemp }

    func fetchWristTemperatureBaseline(days: Int) async throws -> Double? { nil }
}

@Suite("AllDataViewModel")
@MainActor
struct AllDataViewModelTests {
    private let calendar = Calendar.current

    private func day(_ daysAgo: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    }

    private func makeVM(
        hrv: MockAllDataHRVService = .init(),
        sleep: MockAllDataSleepService = .init(),
        steps: MockAllDataStepsService = .init(),
        workout: MockAllDataWorkoutService = .init(),
        body: MockAllDataBodyService = .init(),
        heartRate: MockAllDataHeartRateService = .init(),
        vitals: MockAllDataVitalsService = .init()
    ) -> AllDataViewModel {
        AllDataViewModel(
            hrvService: hrv,
            sleepService: sleep,
            stepsService: steps,
            workoutService: workout,
            bodyService: body,
            heartRateService: heartRate,
            vitalsService: vitals
        )
    }

    @Test("loadInitialData for HRV loads first page and keeps pagination open")
    func loadInitialHRV() async {
        let hrv = MockAllDataHRVService(hrvSamples: [
            HRVSample(value: 42, date: day(1)),
            HRVSample(value: 48, date: day(2)),
        ])
        let vm = makeVM(hrv: hrv)
        vm.configure(category: .hrv)

        await vm.loadInitialData()

        #expect(vm.category == .hrv)
        #expect(vm.dataPoints.count == 2)
        #expect(vm.hasMoreData)
        #expect(vm.isLoading == false)
    }

    @Test("Empty first page marks hasMoreData as false")
    func emptyFirstPageStopsPagination() async {
        let vm = makeVM(hrv: MockAllDataHRVService(hrvSamples: []))
        vm.configure(category: .hrv)

        await vm.loadInitialData()

        #expect(vm.dataPoints.isEmpty)
        #expect(vm.hasMoreData == false)
        #expect(vm.isLoading == false)
    }

    @Test("Sleep category includes only days with positive sleep duration")
    func sleepCategoryFiltersZeroTotals() async {
        let sleepDay = day(1)
        let zeroDay = day(2)

        let sleepService = MockAllDataSleepService(stagesByDay: [
            sleepDay: [
                SleepStage(stage: .core, duration: 7 * 3600, startDate: sleepDay, endDate: sleepDay.addingTimeInterval(7 * 3600)),
            ],
            zeroDay: [
                SleepStage(stage: .awake, duration: 1_800, startDate: zeroDay, endDate: zeroDay.addingTimeInterval(1_800)),
            ],
        ])

        let vm = makeVM(sleep: sleepService)
        vm.configure(category: .sleep)

        await vm.loadInitialData()

        #expect(vm.dataPoints.count == 1)
        #expect(abs(vm.dataPoints[0].value - 420) < 0.001)
    }

    @Test("groupedByDate returns newest date first and points sorted descending")
    func groupedByDateOrdering() {
        let vm = makeVM()

        let today = day(0)
        let older = day(1)
        vm.dataPoints = [
            ChartDataPoint(date: today.addingTimeInterval(300), value: 1),
            ChartDataPoint(date: older.addingTimeInterval(100), value: 2),
            ChartDataPoint(date: today.addingTimeInterval(100), value: 3),
        ]

        let grouped = vm.groupedByDate

        #expect(grouped.count == 2)
        #expect(grouped[0].date > grouped[1].date)
        #expect(grouped[0].points.count == 2)
        #expect(grouped[0].points[0].date > grouped[0].points[1].date)
    }
}
