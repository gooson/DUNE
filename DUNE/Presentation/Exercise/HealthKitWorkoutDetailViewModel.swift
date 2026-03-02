import Observation
import Foundation

@Observable
@MainActor
final class HealthKitWorkoutDetailViewModel {
    var heartRateSummary: HeartRateSummary?
    var effortScore: Double?
    var isLoading = false
    var errorMessage: String?

    private let heartRateService: HeartRateQueryService
    private let effortService: EffortScoreService
    private var loadTask: Task<Void, Never>?

    init(
        heartRateService: HeartRateQueryService = HeartRateQueryService(manager: .shared),
        effortService: EffortScoreService = EffortScoreService(manager: .shared)
    ) {
        self.heartRateService = heartRateService
        self.effortService = effortService
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

            let (hr, effort) = await (hrResult, effortResult)

            guard !Task.isCancelled else { return }
            heartRateSummary = hr
            effortScore = effort
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
}
