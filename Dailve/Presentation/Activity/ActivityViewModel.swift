import Foundation
import Observation
import OSLog

/// ViewModel for the redesigned Activity tab.
/// Loads weekly summary data for exercise, steps, and calories in parallel.
@Observable
@MainActor
final class ActivityViewModel {
    var weeklyExerciseMinutes: [ChartDataPoint] = []
    var weeklySteps: [ChartDataPoint] = []
    var todayExercise: HealthMetric?
    var todaySteps: HealthMetric?
    var recentWorkouts: [WorkoutSummary] = []
    var isLoading = false
    var errorMessage: String?
    var workoutSuggestion: WorkoutSuggestion?

    private let workoutService: WorkoutQuerying
    private let stepsService: StepsQuerying
    private let recommendationService: WorkoutRecommending
    private let library: ExerciseLibraryQuerying

    init(
        workoutService: WorkoutQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        healthKitManager: HealthKitManager = .shared,
        recommendationService: WorkoutRecommending? = nil,
        library: ExerciseLibraryQuerying? = nil
    ) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.recommendationService = recommendationService ?? WorkoutRecommendationService()
        self.library = library ?? ExerciseLibraryService.shared
    }

    // MARK: - Workout Suggestion

    func updateSuggestion(records: [ExerciseRecord]) {
        let snapshots = records.map { record in
            ExerciseRecordSnapshot(
                date: record.date,
                exerciseDefinitionID: record.exerciseDefinitionID,
                primaryMuscles: record.primaryMuscles,
                secondaryMuscles: record.secondaryMuscles,
                completedSetCount: record.completedSets.count
            )
        }
        workoutSuggestion = recommendationService.recommend(from: snapshots, library: library)
    }

    private var loadTask: Task<Void, Never>?

    func loadActivityData() async {
        guard !isLoading else { return }
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        // 3 independent queries — parallel via async let
        async let exerciseTask = safeExerciseFetch()
        async let stepsTask = safeStepsFetch()
        async let workoutsTask = safeWorkoutsFetch()

        let (exerciseResult, stepsResult, workoutsResult) = await (exerciseTask, stepsTask, workoutsTask)

        guard !Task.isCancelled else { return }

        weeklyExerciseMinutes = exerciseResult.weeklyData
        todayExercise = exerciseResult.todayMetric
        weeklySteps = stepsResult.weeklyData
        todaySteps = stepsResult.todayMetric
        recentWorkouts = workoutsResult

        isLoading = false
    }

    // MARK: - Exercise Fetch

    private struct ExerciseResult {
        let weeklyData: [ChartDataPoint]
        let todayMetric: HealthMetric?
    }

    private func safeExerciseFetch() async -> ExerciseResult {
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else {
                return ExerciseResult(weeklyData: [], todayMetric: nil)
            }

            let workouts = try await workoutService.fetchWorkouts(
                start: weekStart, end: Date()
            )

            // Group by day
            var dailyMinutes: [Date: Double] = [:]
            for workout in workouts {
                let dayStart = calendar.startOfDay(for: workout.date)
                dailyMinutes[dayStart, default: 0] += workout.duration / 60.0
            }

            // Build 7-day chart data (fill gaps with 0)
            var weeklyData: [ChartDataPoint] = []
            for dayOffset in (0..<7).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                weeklyData.append(ChartDataPoint(date: dayStart, value: dailyMinutes[dayStart] ?? 0))
            }

            // Today metric
            let todayMinutes = dailyMinutes[today] ?? 0
            let todayMetric = HealthMetric(
                id: "activity-exercise",
                name: "Exercise",
                value: todayMinutes,
                unit: "min",
                change: nil,
                date: Date(),
                category: .exercise
            )

            return ExerciseResult(weeklyData: weeklyData, todayMetric: todayMetric)
        } catch {
            AppLogger.ui.error("Activity exercise fetch failed: \(error.localizedDescription)")
            return ExerciseResult(weeklyData: [], todayMetric: nil)
        }
    }

    // MARK: - Steps Fetch (uses StatisticsCollection for efficiency)

    private struct StepsResult {
        let weeklyData: [ChartDataPoint]
        let todayMetric: HealthMetric?
    }

    private func safeStepsFetch() async -> StepsResult {
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else {
                return StepsResult(weeklyData: [], todayMetric: nil)
            }

            let collection = try await stepsService.fetchStepsCollection(
                start: weekStart, end: Date(), interval: DateComponents(day: 1)
            )

            // Build lookup from collection results
            var dailySteps: [Date: Double] = [:]
            for entry in collection {
                let dayStart = calendar.startOfDay(for: entry.date)
                dailySteps[dayStart] = entry.sum
            }

            // Build 7-day chart data (fill gaps with 0)
            var weeklyData: [ChartDataPoint] = []
            for dayOffset in (0..<7).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                weeklyData.append(ChartDataPoint(date: dayStart, value: dailySteps[dayStart] ?? 0))
            }

            // Today metric
            let todaySteps = dailySteps[today] ?? 0
            let todayMetric = HealthMetric(
                id: "activity-steps",
                name: "Steps",
                value: todaySteps,
                unit: "",
                change: nil,
                date: Date(),
                category: .steps
            )

            return StepsResult(weeklyData: weeklyData, todayMetric: todayMetric)
        } catch {
            AppLogger.ui.error("Activity steps fetch failed: \(error.localizedDescription)")
            return StepsResult(weeklyData: [], todayMetric: nil)
        }
    }

    // MARK: - Recent Workouts

    private func safeWorkoutsFetch() async -> [WorkoutSummary] {
        do {
            return try await workoutService.fetchWorkouts(days: 7)
        } catch {
            AppLogger.ui.error("Activity workouts fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}
