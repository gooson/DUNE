import Foundation
import SwiftData

/// Reads the app's active store and projects models before crossing an async boundary.
@MainActor
final class HealthQueryService: HealthQuerying {
    static let shared = HealthQueryService()
    static let maximumRecords = 2_000

    var container: ModelContainer?
    var sharedHealthDataService: (any SharedHealthDataService)?
    let workoutService: any WorkoutQuerying
    let bodyService: any BodyCompositionQuerying
    let sleepService: any SleepQuerying
    let nowProvider: @Sendable () -> Date
    let calendar: Calendar
    var protectedDataProvider: @MainActor @Sendable () -> Bool
    let tombstonesProvider: @MainActor @Sendable () -> Set<String>

    init(
        container: ModelContainer? = nil,
        sharedHealthDataService: (any SharedHealthDataService)? = nil,
        workoutService: any WorkoutQuerying = WorkoutQueryService(manager: .shared),
        bodyService: any BodyCompositionQuerying = BodyCompositionQueryService(manager: .shared),
        sleepService: any SleepQuerying = SleepQueryService(manager: .shared),
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = .current,
        protectedDataProvider: @escaping @MainActor @Sendable () -> Bool = { true },
        tombstonesProvider: @escaping @MainActor @Sendable () -> Set<String> = { DeletedWorkoutTombstoneStore.shared.tombstonedIDs }
    ) {
        self.container = container
        self.sharedHealthDataService = sharedHealthDataService
        self.workoutService = workoutService
        self.bodyService = bodyService
        self.sleepService = sleepService
        self.nowProvider = nowProvider
        self.calendar = calendar
        self.protectedDataProvider = protectedDataProvider
        self.tombstonesProvider = tombstonesProvider
    }

    func configure(
        container: ModelContainer,
        sharedHealthDataService: any SharedHealthDataService,
        protectedDataProvider: @escaping @MainActor @Sendable () -> Bool = { true }
    ) {
        self.container = container
        self.sharedHealthDataService = sharedHealthDataService
        self.protectedDataProvider = protectedDataProvider
    }

    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        try Task.checkCancellation()
        let now = nowProvider()
        let interval = request.interval ?? defaultPeriod(for: request.kind).interval(endingAt: now, calendar: calendar)
        guard protectedDataProvider() else {
            return result(request.kind, status: .locked, interval: interval,
                          summary: String(localized: "Unlock your device to read health records.", locale: HealthQueryLocalization.locale))
        }
        guard interval.start.timeIntervalSinceReferenceDate.isFinite,
              interval.end.timeIntervalSinceReferenceDate.isFinite,
              interval.duration > 0, interval.duration <= 367 * 86_400,
              interval.end <= now.addingTimeInterval(1),
              (1...100).contains(request.limit),
              (request.searchText?.count ?? 0) <= 500,
              (request.exerciseID?.count ?? 0) <= 200,
              (request.workoutID?.count ?? 0) <= 200 else {
            return result(request.kind, status: .invalidRequest, interval: interval,
                          summary: String(localized: "Choose a valid period of up to one year and a shorter search.", locale: HealthQueryLocalization.locale))
        }
        guard container != nil else {
            return result(request.kind, status: .unavailable, interval: interval,
                          summary: String(localized: "App records are not available yet. Open DUNE and try again.", locale: HealthQueryLocalization.locale))
        }
        let response: HealthQueryResult
        switch request.kind {
        case .latestBody, .bodyTrend:
            response = try await bodyResult(request, interval: interval)
        case .sleep:
            response = try await sleepResult(request, interval: interval)
        case .condition:
            response = try await conditionResult(request, interval: interval)
        case .metricComparison:
            response = try await comparisonResult(request, interval: interval)
        case .longAnalysis:
            response = try await analysisResult(request, interval: interval)
        case .latestWorkout, .workoutSummary, .strengthSets, .personalRecord,
             .cardioDetail, .workoutComparison, .memoSearch, .report:
            response = try await workoutResult(request, interval: interval)
        }
        try Task.checkCancellation()
        // Protected data can become unavailable while HealthKit requests are in flight.
        guard protectedDataProvider() else {
            return result(request.kind, status: .locked, interval: interval,
                          summary: String(localized: "Unlock your device to read health records.", locale: HealthQueryLocalization.locale))
        }
        return response
    }

    func defaultPeriod(for kind: HealthQueryKind) -> HealthQueryPeriod {
        switch kind {
        case .sleep, .condition: .today
        case .workoutSummary, .report: .thisWeek
        case .bodyTrend, .metricComparison, .memoSearch, .longAnalysis: .last30Days
        case .latestWorkout, .strengthSets, .personalRecord, .cardioDetail, .latestBody, .workoutComparison: .last365Days
        }
    }

    func result(
        _ kind: HealthQueryKind, status: HealthQueryStatus = .available, interval: DateInterval,
        metrics: [HealthQueryMetric] = [], series: [HealthQuerySeries] = [],
        records: [HealthQueryWorkoutSnapshot] = [], sources: [HealthQuerySource] = [],
        summary: String, limitations: [String] = [], isComplete: Bool = true
    ) -> HealthQueryResult {
        var spokenSummary = summary
        if [.latestBody, .bodyTrend, .sleep, .condition].contains(kind), !metrics.isEmpty {
            spokenSummary += " " + metricSummary(metrics)
        }
        if !isComplete {
            spokenSummary += " " + String(localized: "Some records could not be read, so this answer may be incomplete.", locale: HealthQueryLocalization.locale)
        }
        return HealthQueryResult(kind: kind, status: status, title: Self.title(for: kind), generatedAt: nowProvider(),
                          interval: interval, metrics: metrics, series: series, records: records,
                          sources: sources, spokenSummary: spokenSummary, limitations: limitations, isComplete: isComplete)
    }

    static func title(for kind: HealthQueryKind) -> String {
        switch kind {
        case .latestWorkout: String(localized: "Latest Workout", locale: HealthQueryLocalization.locale)
        case .workoutSummary: String(localized: "Workout Summary", locale: HealthQueryLocalization.locale)
        case .strengthSets: String(localized: "Completed Strength Sets", locale: HealthQueryLocalization.locale)
        case .personalRecord: String(localized: "Highest Recorded Weight", locale: HealthQueryLocalization.locale)
        case .cardioDetail: String(localized: "Latest Cardio Workout", locale: HealthQueryLocalization.locale)
        case .latestBody: String(localized: "Latest Body Measurements", locale: HealthQueryLocalization.locale)
        case .bodyTrend: String(localized: "Body Measurement Change", locale: HealthQueryLocalization.locale)
        case .sleep: String(localized: "Sleep Records", locale: HealthQueryLocalization.locale)
        case .condition: String(localized: "Condition and Recovery", locale: HealthQueryLocalization.locale)
        case .metricComparison: String(localized: "Workout and Sleep Comparison", locale: HealthQueryLocalization.locale)
        case .workoutComparison: String(localized: "Compare Workout Records", locale: HealthQueryLocalization.locale)
        case .memoSearch: String(localized: "Search Workout Notes", locale: HealthQueryLocalization.locale)
        case .report: String(localized: "Workout Report", locale: HealthQueryLocalization.locale)
        case .longAnalysis: String(localized: "Health Record Analysis", locale: HealthQueryLocalization.locale)
        }
    }

    static func valid(_ value: Double?, in range: ClosedRange<Double>) -> Double? {
        guard let value, value.isFinite, range.contains(value) else { return nil }
        return value
    }

    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    func dateText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: HealthQueryLocalization.locale))
    }

    func number(_ value: Double, digits: Int = 0) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).grouping(.automatic).locale(HealthQueryLocalization.locale))
    }
}

extension HealthQueryService {
    struct WorkoutLoad {
        var records: [HealthQueryWorkoutSnapshot]
        var limitations: [String]
        var complete: Bool
    }

    func loadWorkouts(in interval: DateInterval) async throws -> WorkoutLoad {
        guard let container else { throw HealthQueryServiceError.notConfigured }
        let context = ModelContext(container)
        let start = interval.start
        let end = interval.end
        var descriptor = FetchDescriptor<ExerciseRecord>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\ExerciseRecord.date, order: .reverse)]
        )
        descriptor.fetchLimit = Self.maximumRecords + 1
        let models = try context.fetch(descriptor)
        let local = models.prefix(Self.maximumRecords).compactMap(Self.projectWorkout)
        var limitations: [String] = []
        var complete = models.count <= Self.maximumRecords
        if !complete { limitations.append(String(localized: "The result is limited to the most recent 2,000 records in this period.", locale: HealthQueryLocalization.locale)) }
        let remote: [HealthQueryWorkoutSnapshot]
        do {
            let workouts = try await workoutService.fetchWorkouts(start: start, end: end)
            if workouts.count > Self.maximumRecords {
                complete = false
                limitations.append(String(localized: "Health app results are limited to the most recent 2,000 records in this period.", locale: HealthQueryLocalization.locale))
            }
            remote = workouts.filter { $0.date >= start && $0.date < end }
                .sorted { $0.date > $1.date }.prefix(Self.maximumRecords).compactMap(Self.projectWorkout)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            AppLogger.healthKit.notice("Health query workouts unavailable: \(String(describing: error), privacy: .private)")
            remote = []
            complete = false
            limitations.append(String(localized: "Health app workouts could not be read. Available DUNE records are shown.", locale: HealthQueryLocalization.locale))
        }
        try Task.checkCancellation()
        return WorkoutLoad(records: Self.mergeWorkouts(local: local, healthKit: remote, tombstones: tombstonesProvider()),
                           limitations: limitations, complete: complete)
    }

    static func projectWorkout(_ record: ExerciseRecord) -> HealthQueryWorkoutSnapshot? {
        guard record.date.timeIntervalSinceReferenceDate.isFinite else { return nil }
        let sets = (record.sets ?? []).filter { $0.isCompleted && $0.setType != .warmup }
            .sorted { $0.setNumber < $1.setNumber }.map { set in
                HealthQuerySetSnapshot(id: set.id.uuidString, number: set.setNumber,
                                       weightKilograms: valid(set.weight, in: 0...500),
                                       reps: set.reps.flatMap { (1...100).contains($0) ? $0 : nil },
                                       durationSeconds: valid(set.duration, in: 0.001...604_800),
                                       distanceMeters: valid(set.distance, in: 0.001...1_000_000))
            }
        let duration = valid(record.duration, in: 0.001...31_622_400)
        guard duration != nil || !sets.isEmpty else { return nil }
        let activityType = WorkoutActivityType(rawValue: record.exerciseType)
            ?? record.exerciseDefinitionID.flatMap { WorkoutActivityType(rawValue: $0) ?? WorkoutActivityType.infer(from: $0) }
            ?? WorkoutActivityType.infer(from: record.exerciseType)
        return HealthQueryWorkoutSnapshot(
            id: "app:\(record.id.uuidString)", localRecordID: record.id,
            healthKitWorkoutID: record.healthKitWorkoutID.flatMap { $0.isEmpty ? nil : $0 },
            exerciseID: record.exerciseDefinitionID, name: String(record.exerciseType.prefix(200)),
            activityType: activityType, date: record.date, durationSeconds: duration,
            distanceMeters: valid(record.distance, in: 0.001...1_000_000),
            averagePaceSecondsPerKm: valid(record.averagePaceSecondsPerKm, in: 1...86_400),
            calories: valid(record.bestCalories, in: 0...100_000), completedSets: sets,
            memo: String(record.memo.prefix(500)), source: .app
        )
    }

    static func projectWorkout(_ record: WorkoutSummary) -> HealthQueryWorkoutSnapshot? {
        guard !record.id.isEmpty, record.date.timeIntervalSinceReferenceDate.isFinite,
              let duration = valid(record.duration, in: 0.001...31_622_400) else { return nil }
        return HealthQueryWorkoutSnapshot(
            id: "healthkit:\(record.id)", healthKitWorkoutID: record.id, name: String(record.type.prefix(200)),
            activityType: record.activityType, date: record.date, durationSeconds: duration,
            distanceMeters: valid(record.distance, in: 0.001...1_000_000),
            averagePaceSecondsPerKm: valid(record.averagePace, in: 1...86_400),
            averageHeartRate: valid(record.heartRateAvg, in: 20...300), calories: valid(record.calories, in: 0...100_000),
            source: .healthKit, isFromThisApp: record.isFromThisApp
        )
    }

    static func mergeWorkouts(
        local: [HealthQueryWorkoutSnapshot], healthKit: [HealthQueryWorkoutSnapshot], tombstones: Set<String>
    ) -> [HealthQueryWorkoutSnapshot] {
        let local = local.filter { record in
            guard let id = record.healthKitWorkoutID else { return true }
            return !tombstones.contains(id)
        }
        let remote = healthKit.filter { !tombstones.contains($0.healthKitWorkoutID ?? "") }
        let byID = Dictionary(remote.compactMap { record in record.healthKitWorkoutID.map { ($0, record) } }, uniquingKeysWith: { first, _ in first })
        let enriched = local.map { record in
            guard let id = record.healthKitWorkoutID, let remote = byID[id] else { return record }
            var enriched = record
            enriched.averageHeartRate = record.averageHeartRate ?? remote.averageHeartRate
            enriched.distanceMeters = record.distanceMeters ?? remote.distanceMeters
            enriched.averagePaceSecondsPerKm = record.averagePaceSecondsPerKm ?? remote.averagePaceSecondsPerKm
            enriched.calories = record.calories ?? remote.calories
            return enriched
        }
        let linkedIDs = Set(local.compactMap(\.healthKitWorkoutID))
        let remaining = remote.filter { remote in
            if let id = remote.healthKitWorkoutID, linkedIDs.contains(id) { return false }
            guard remote.isFromThisApp else { return true }
            return !local.contains { local in
                guard local.healthKitWorkoutID == nil,
                      abs(local.date.timeIntervalSince(remote.date)) < 120 else { return false }
                if let localType = local.activityType, localType == remote.activityType { return true }
                return remote.activityType?.category == .strength && !local.completedSets.isEmpty
            }
        }
        return (enriched + remaining).sorted { $0.date > $1.date }
    }
}

enum HealthQueryServiceError: Error {
    case notConfigured
}
