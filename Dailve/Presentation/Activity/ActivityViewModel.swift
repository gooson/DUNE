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

    private let workoutService: WorkoutQuerying
    private let stepsService: StepsQuerying

    init(
        workoutService: WorkoutQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
    }

    func loadActivityData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // 3 independent queries — parallel via async let
        async let exerciseTask = safeExerciseFetch()
        async let stepsTask = safeStepsFetch()
        async let workoutsTask = safeWorkoutsFetch()

        let (exerciseResult, stepsResult, workoutsResult) = await (exerciseTask, stepsTask, workoutsTask)

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
            let workouts = try await workoutService.fetchWorkouts(days: 7)
            let calendar = Calendar.current

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
            let today = calendar.startOfDay(for: Date())
            let todayMinutes = dailyMinutes[today] ?? 0
            let todayMetric: HealthMetric? = HealthMetric(
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

    // MARK: - Steps Fetch

    private struct StepsResult {
        let weeklyData: [ChartDataPoint]
        let todayMetric: HealthMetric?
    }

    private func safeStepsFetch() async -> StepsResult {
        do {
            let calendar = Calendar.current
            var weeklyData: [ChartDataPoint] = []

            try await withThrowingTaskGroup(of: (Date, Double?).self) { group in
                for dayOffset in 0..<7 {
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
                    group.addTask { [stepsService] in
                        let steps = try await stepsService.fetchSteps(for: date)
                        return (calendar.startOfDay(for: date), steps)
                    }
                }

                for try await (date, steps) in group {
                    weeklyData.append(ChartDataPoint(date: date, value: steps ?? 0))
                }
            }

            weeklyData.sort(by: { $0.date < $1.date })

            // Today metric
            let today = calendar.startOfDay(for: Date())
            let todaySteps = weeklyData.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.value ?? 0
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
