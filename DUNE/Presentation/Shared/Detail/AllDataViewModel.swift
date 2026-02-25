import Foundation
import Observation
import OSLog

/// ViewModel for AllDataView — loads paginated historical data for a metric.
@Observable
@MainActor
final class AllDataViewModel {
    var dataPoints: [ChartDataPoint] = []
    var isLoading = false
    var hasMoreData = true

    private(set) var category: HealthMetric.Category = .hrv

    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying
    private let stepsService: StepsQuerying
    private let workoutService: WorkoutQuerying
    private let bodyService: BodyCompositionQuerying
    private let heartRateService: HeartRateQuerying
    private let vitalsService: VitalsQuerying

    private var currentPage = 0
    private let pageSize = 30 // days per page

    init(
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        workoutService: WorkoutQuerying? = nil,
        bodyService: BodyCompositionQuerying? = nil,
        heartRateService: HeartRateQuerying? = nil,
        vitalsService: VitalsQuerying? = nil,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.bodyService = bodyService ?? BodyCompositionQueryService(manager: healthKitManager)
        self.heartRateService = heartRateService ?? HeartRateQueryService(manager: healthKitManager)
        self.vitalsService = vitalsService ?? VitalsQueryService(manager: healthKitManager)
    }

    func configure(category: HealthMetric.Category) {
        self.category = category
    }

    func loadInitialData() async {
        currentPage = 0
        dataPoints = []
        hasMoreData = true
        await loadNextPage()
    }

    private var pageTask: Task<Void, Never>?

    func loadNextPage() async {
        guard !isLoading, hasMoreData else { return }
        pageTask?.cancel()
        isLoading = true

        let startDay = currentPage * pageSize
        let endDay = startDay + pageSize

        do {
            let newPoints = try await fetchData(fromDaysAgo: endDay, toDaysAgo: startDay)
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            if newPoints.isEmpty {
                hasMoreData = false
            } else {
                dataPoints.append(contentsOf: newPoints)
                currentPage += 1
            }
        } catch {
            AppLogger.ui.error("AllData load failed: \(error.localizedDescription)")
            hasMoreData = false
        }

        isLoading = false
    }

    // MARK: - Grouped Data

    /// Data grouped by date section (newest first).
    var groupedByDate: [(date: Date, points: [ChartDataPoint])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dataPoints) { point in
            calendar.startOfDay(for: point.date)
        }
        return grouped
            .map { (date: $0.key, points: $0.value.sorted(by: { $0.date > $1.date })) }
            .sorted(by: { $0.date > $1.date })
    }

    // MARK: - Private

    private func fetchData(fromDaysAgo: Int, toDaysAgo: Int) async throws -> [ChartDataPoint] {
        switch category {
        case .hrv:
            let samples = try await hrvService.fetchHRVSamples(days: fromDaysAgo)
            let calendar = Calendar.current
            let cutoff = calendar.date(byAdding: .day, value: -toDaysAgo, to: Date()) ?? Date()
            return samples
                .filter { $0.date <= cutoff }
                .map { ChartDataPoint(date: $0.date, value: $0.value) }

        case .rhr:
            var points: [ChartDataPoint] = []
            let calendar = Calendar.current
            try await withThrowingTaskGroup(of: (Date, Double?).self) { group in
                for dayOffset in toDaysAgo..<fromDaysAgo {
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
                    group.addTask { [hrvService] in
                        let rhr = try await hrvService.fetchRestingHeartRate(for: date)
                        return (date, rhr)
                    }
                }
                for try await (date, rhr) in group {
                    if let rhr { points.append(ChartDataPoint(date: date, value: rhr)) }
                }
            }
            return points.sorted(by: { $0.date > $1.date })

        case .sleep:
            var points: [ChartDataPoint] = []
            let calendar = Calendar.current
            try await withThrowingTaskGroup(of: (Date, Double).self) { group in
                for dayOffset in toDaysAgo..<fromDaysAgo {
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
                    group.addTask { [sleepService] in
                        let stages = try await sleepService.fetchSleepStages(for: date)
                        let total = stages.reduce(0.0) { $0 + $1.duration } / 60.0
                        return (date, total)
                    }
                }
                for try await (date, total) in group {
                    if total > 0 { points.append(ChartDataPoint(date: date, value: total)) }
                }
            }
            return points.sorted(by: { $0.date > $1.date })

        case .steps:
            var points: [ChartDataPoint] = []
            let calendar = Calendar.current
            try await withThrowingTaskGroup(of: (Date, Double?).self) { group in
                for dayOffset in toDaysAgo..<fromDaysAgo {
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
                    group.addTask { [stepsService] in
                        let steps = try await stepsService.fetchSteps(for: date)
                        return (date, steps)
                    }
                }
                for try await (date, steps) in group {
                    if let steps { points.append(ChartDataPoint(date: date, value: steps)) }
                }
            }
            return points.sorted(by: { $0.date > $1.date })

        case .exercise:
            let workouts = try await workoutService.fetchWorkouts(days: fromDaysAgo)
            let calendar = Calendar.current
            let cutoff = calendar.date(byAdding: .day, value: -toDaysAgo, to: Date()) ?? Date()
            return workouts
                .filter { $0.date <= cutoff }
                .map { ChartDataPoint(date: $0.date, value: $0.duration / 60.0) }
                .sorted(by: { $0.date > $1.date })

        case .weight:
            let samples = try await bodyService.fetchWeight(days: fromDaysAgo)
            let calendar = Calendar.current
            let cutoff = calendar.date(byAdding: .day, value: -toDaysAgo, to: Date()) ?? Date()
            return samples
                .filter { $0.date <= cutoff }
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })

        case .bmi:
            let start = Calendar.current.date(byAdding: .day, value: -fromDaysAgo, to: Date()) ?? Date()
            let cutoff = Calendar.current.date(byAdding: .day, value: -toDaysAgo, to: Date()) ?? Date()
            let samples = try await bodyService.fetchBMI(start: start, end: cutoff)
            return samples
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })

        case .heartRate:
            let samples = try await heartRateService.fetchHeartRateHistory(days: fromDaysAgo)
            return samples
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })

        case .bodyFat:
            let samples = try await bodyService.fetchBodyFat(days: fromDaysAgo)
            return samples
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })

        case .leanBodyMass:
            let samples = try await bodyService.fetchLeanBodyMass(days: fromDaysAgo)
            return samples
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })

        case .spo2:
            let samples = try await vitalsService.fetchSpO2Collection(days: fromDaysAgo)
            return samples
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })

        case .respiratoryRate:
            let samples = try await vitalsService.fetchRespiratoryRateCollection(days: fromDaysAgo)
            return samples
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })

        case .vo2Max:
            let samples = try await vitalsService.fetchVO2MaxHistory(days: fromDaysAgo)
            return samples
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })

        case .heartRateRecovery:
            let samples = try await vitalsService.fetchHeartRateRecoveryHistory(days: fromDaysAgo)
            return samples
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })

        case .wristTemperature:
            let samples = try await vitalsService.fetchWristTemperatureCollection(days: fromDaysAgo)
            return samples
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
                .sorted(by: { $0.date > $1.date })
        }
    }
}
