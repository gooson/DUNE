import Foundation
import Observation
import OSLog

/// ViewModel for AllDataView — loads paginated historical data for a metric.
@Observable
@MainActor
final class AllDataViewModel {
    var dataPoints: [ChartDataPoint] = [] {
        didSet { invalidateGroupedByDate() }
    }
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
    private let breathingDisturbanceService: BreathingDisturbanceQuerying

    private let historyService: any MetricHistoryQuerying
    private var pageEnd = Date()
    private let pageSize = 30 // calendar days per page
    private var pageRequestID = 0

    init(
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        workoutService: WorkoutQuerying? = nil,
        bodyService: BodyCompositionQuerying? = nil,
        heartRateService: HeartRateQuerying? = nil,
        vitalsService: VitalsQuerying? = nil,
        breathingDisturbanceService: BreathingDisturbanceQuerying? = nil,
        historyService: (any MetricHistoryQuerying)? = nil,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.historyService = historyService ?? MetricHistoryQueryService(manager: healthKitManager)
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.bodyService = bodyService ?? BodyCompositionQueryService(manager: healthKitManager)
        self.heartRateService = heartRateService ?? HeartRateQueryService(manager: healthKitManager)
        self.vitalsService = vitalsService ?? VitalsQueryService(manager: healthKitManager)
        self.breathingDisturbanceService = breathingDisturbanceService ?? BreathingDisturbanceQueryService(manager: healthKitManager)
    }

    func configure(category: HealthMetric.Category) {
        self.category = category
    }

    func loadInitialData() async {
        resetPageRequests()
        pageEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        dataPoints = []
        hasMoreData = true
        isLoading = false
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading, hasMoreData else { return }
        let requestID = beginPageRequest()
        isLoading = true
        defer { finishPageRequest(requestID) }

        do {
            var end = pageEnd
            while isCurrentPageRequest(requestID) {
                let start = Calendar.current.date(byAdding: .day, value: -pageSize, to: end) ?? end
                let points = try await fetchData(start: start, end: end)
                guard isCurrentPageRequest(requestID) else { return }
                if !points.isEmpty {
                    dataPoints.append(contentsOf: points)
                    pageEnd = start
                    return
                }
                // An empty month is not the end of history. Jump directly to the
                // previous sample rather than issuing one query for every empty day.
                guard let previous = try await historyService.latestDate(for: category, before: start) else {
                    guard isCurrentPageRequest(requestID) else { return }
                    hasMoreData = false
                    return
                }
                guard previous < start else { throw HistoryError.invalidCursor }
                let day = Calendar.current.startOfDay(for: previous)
                end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? start
                // Sleep samples can begin the evening before their reporting day.
                if category == .sleep {
                    end = min(start, end.addingTimeInterval(86400))
                }
                end = min(start, end)
                await Task.yield()
            }
        } catch {
            guard isCurrentPageRequest(requestID) else { return }
            AppLogger.ui.error("AllData load failed: \(error.localizedDescription)")
            hasMoreData = false
        }
    }

    private enum HistoryError: Error { case invalidCursor }

    // MARK: - Grouped Data

    /// Data grouped by date section (newest first). Cached and invalidated on data change.
    private(set) var groupedByDate: [(date: Date, points: [ChartDataPoint])] = []

    private func invalidateGroupedByDate() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dataPoints) { point in
            calendar.startOfDay(for: point.date)
        }
        groupedByDate = grouped
            .map { (date: $0.key, points: $0.value.sorted(by: { $0.date > $1.date })) }
            .sorted(by: { $0.date > $1.date })
    }

    // MARK: - Private

    private func beginPageRequest() -> Int {
        pageRequestID += 1
        return pageRequestID
    }

    private func resetPageRequests() {
        pageRequestID += 1
    }

    private func isCurrentPageRequest(_ requestID: Int) -> Bool {
        requestID == pageRequestID && !Task.isCancelled
    }

    private func finishPageRequest(_ requestID: Int) {
        if requestID == pageRequestID {
            isLoading = false
        }
    }

    private func fetchData(start: Date, end: Date) async throws -> [ChartDataPoint] {
        let points: [ChartDataPoint]
        switch category {
        case .hrv:
            points = try await hrvService.fetchHRVSamples(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .rhr:
            points = try await hrvService.fetchRHRCollection(start: start, end: end, interval: DateComponents(day: 1))
                .map { ChartDataPoint(date: $0.date, value: $0.average) }
        case .sleep:
            let service = sleepService
            points = try await withThrowingTaskGroup(of: ChartDataPoint?.self) { group in
                var day = start
                while day < end {
                    let date = day
                    group.addTask {
                        let stages = try await service.fetchSleepStages(for: date).filter { $0.stage != .awake }
                        let minutes = stages.reduce(0.0) { $0 + $1.duration } / 60
                        guard minutes > 0 else { return nil }
                        return ChartDataPoint(date: date, value: minutes, displayDate: stages.map(\.startDate).min())
                    }
                    day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? end
                }
                var result: [ChartDataPoint] = []
                for try await point in group {
                    if let point { result.append(point) }
                }
                return result
            }
        case .steps:
            points = try await stepsService.fetchStepsCollection(start: start, end: end, interval: DateComponents(day: 1))
                .map { ChartDataPoint(date: $0.date, value: $0.sum) }
        case .exercise:
            points = try await workoutService.fetchWorkouts(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.duration / 60.0) }
        case .weight:
            points = try await bodyService.fetchWeight(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .bmi:
            points = try await bodyService.fetchBMI(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .bodyFat:
            points = try await bodyService.fetchBodyFat(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .leanBodyMass:
            points = try await bodyService.fetchLeanBodyMass(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .heartRate:
            points = try await heartRateService.fetchHeartRateHistory(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .spo2:
            points = try await vitalsService.fetchSpO2Collection(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .respiratoryRate:
            points = try await vitalsService.fetchRespiratoryRateCollection(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .vo2Max:
            points = try await vitalsService.fetchVO2MaxHistory(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .heartRateRecovery:
            points = try await vitalsService.fetchHeartRateRecoveryHistory(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .wristTemperature:
            points = try await vitalsService.fetchWristTemperatureCollection(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        case .breathingDisturbances:
            points = try await breathingDisturbanceService.fetchNightlyDisturbances(start: start, end: end)
                .map { ChartDataPoint(date: $0.date, value: $0.value) }
        }
        return await Task.detached(priority: .userInitiated) {
            // Statistics buckets and raw samples follow the same half-open boundary.
            points.filter { $0.date >= start && $0.date < end }.sorted { $0.date > $1.date }
        }.value
    }
}
