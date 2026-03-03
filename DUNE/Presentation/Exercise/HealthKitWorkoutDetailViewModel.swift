import Observation
import Foundation
import HealthKit

@Observable
@MainActor
final class HealthKitWorkoutDetailViewModel {
    enum StepRange: String, CaseIterable, Sendable, Identifiable {
        case workout
        case day
        case week

        var id: String { rawValue }

        var title: String {
            switch self {
            case .workout: String(localized: "Workout")
            case .day: String(localized: "Day")
            case .week: String(localized: "Week")
            }
        }
    }

    var heartRateSummary: HeartRateSummary?
    var effortScore: Double?
    var isLoading = false
    var errorMessage: String?
    var selectedStepRange: StepRange = .workout
    var workoutStepCount: Double?
    var dayStepCount: Double?
    var weekStepCount: Double?

    private let heartRateService: HeartRateQueryService
    private let effortService: EffortScoreService
    private let healthKitManager: HealthKitManager
    private var loadTask: Task<Void, Never>?

    init(
        heartRateService: HeartRateQueryService = HeartRateQueryService(manager: .shared),
        effortService: EffortScoreService = EffortScoreService(manager: .shared),
        healthKitManager: HealthKitManager = .shared
    ) {
        self.heartRateService = heartRateService
        self.effortService = effortService
        self.healthKitManager = healthKitManager
    }

    func loadDetail(workoutID: String) {
        loadTask?.cancel()
        loadTask = Task {
            isLoading = true
            defer {
                if !Task.isCancelled { isLoading = false }
            }

            async let hrResult = safeHeartRateFetch(workoutID: workoutID)
            async let effortResult = safeEffortFetch(workoutID: workoutID)
            async let stepResult = safeStepRangeFetch(workoutID: workoutID)

            let (hr, effort, steps) = await (hrResult, effortResult, stepResult)

            guard !Task.isCancelled else { return }
            heartRateSummary = hr
            effortScore = effort
            workoutStepCount = steps.workout
            dayStepCount = steps.day
            weekStepCount = steps.week
        }
    }

    func stepCount(for workout: WorkoutSummary, range: StepRange) -> Double? {
        switch range {
        case .workout:
            if let summarySteps = workout.stepCount, summarySteps > 0 {
                return summarySteps
            }
            return workoutStepCount
        case .day:
            return dayStepCount
        case .week:
            return weekStepCount
        }
    }

    func heartRateAverage(for workout: WorkoutSummary) -> Double? {
        if let avg = workout.heartRateAvg, avg > 0 {
            return avg
        }
        guard let summary = heartRateSummary,
              !summary.isEmpty,
              summary.average > 0 else {
            return nil
        }
        return summary.average
    }

    func heartRateMax(for workout: WorkoutSummary) -> Double? {
        if let max = workout.heartRateMax, max > 0 {
            return max
        }
        guard let summary = heartRateSummary,
              !summary.isEmpty,
              summary.max > 0 else {
            return nil
        }
        return summary.max
    }

    private func safeHeartRateFetch(workoutID: String) async -> HeartRateSummary? {
        do {
            return try await heartRateService.fetchHeartRateSummary(forWorkoutID: workoutID)
        } catch {
            return nil
        }
    }

    private func safeEffortFetch(workoutID: String) async -> Double? {
        do {
            return try await effortService.fetchEffortScore(for: workoutID)
        } catch {
            return nil
        }
    }

    private func safeStepRangeFetch(workoutID: String) async -> (workout: Double?, day: Double?, week: Double?) {
        do {
            return try await fetchStepRanges(workoutID: workoutID)
        } catch {
            return (nil, nil, nil)
        }
    }

    private func fetchStepRanges(workoutID: String) async throws -> (workout: Double?, day: Double?, week: Double?) {
        let stepType = HKQuantityType(.stepCount)
        try await healthKitManager.ensureNotDenied(for: stepType)

        guard let uuid = UUID(uuidString: workoutID) else {
            return (nil, nil, nil)
        }

        let workoutDescriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForObject(with: uuid))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )

        let workouts = try await healthKitManager.execute(workoutDescriptor)
        guard let workout = workouts.first else {
            return (nil, nil, nil)
        }

        let calendar = Calendar.current
        let workoutStart = workout.startDate
        let workoutEnd = workout.endDate
        let dayStart = calendar.startOfDay(for: workoutStart)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? workoutEnd
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: workoutStart)

        async let workoutSteps = fetchStepSum(
            quantityType: stepType,
            start: workoutStart,
            end: workoutEnd
        )
        async let daySteps = fetchStepSum(
            quantityType: stepType,
            start: dayStart,
            end: dayEnd
        )
        async let weekSteps = fetchStepSum(
            quantityType: stepType,
            start: weekInterval?.start,
            end: weekInterval?.end
        )

        let resolvedWorkout = try await workoutSteps
        let resolvedDay = try await daySteps
        let resolvedWeek = try await weekSteps

        return (
            resolvedWorkout.flatMap { $0 > 0 ? $0 : nil },
            resolvedDay.flatMap { $0 > 0 ? $0 : nil },
            resolvedWeek.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    private func fetchStepSum(
        quantityType: HKQuantityType,
        start: Date?,
        end: Date?
    ) async throws -> Double? {
        guard let start, let end, end > start else { return nil }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: quantityType, predicate: predicate),
            options: .cumulativeSum
        )

        let statistics = try await healthKitManager.executeStatistics(descriptor)
        return statistics?.sumQuantity()?.doubleValue(for: .count())
    }
}
