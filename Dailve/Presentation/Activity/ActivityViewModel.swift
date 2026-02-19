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
    var trainingLoadData: [TrainingLoadDataPoint] = []
    var isLoading = false
    var errorMessage: String?
    var workoutSuggestion: WorkoutSuggestion?
    var fatigueStates: [MuscleFatigueState] = []

    /// Weekly training goal in active days.
    let weeklyGoal: Int = 5

    // MARK: - Recent Workouts (cached metrics)

    var recentWorkouts: [WorkoutSummary] = [] {
        didSet { invalidateWorkoutCache() }
    }

    /// Last workout day's total calories from recent workouts.
    private(set) var lastWorkoutCalories: Double = 0

    /// Last workout day's total exercise minutes from recent workouts.
    private(set) var lastWorkoutMinutes: Double = 0

    /// Number of active days (at least 1 workout) in the last 7 days.
    private(set) var activeDays: Int = 0

    private func invalidateWorkoutCache() {
        let calendar = Calendar.current
        let lastDate = recentWorkouts
            .map { calendar.startOfDay(for: $0.date) }
            .max()

        if let lastDate {
            let lastDayWorkouts = recentWorkouts
                .filter { calendar.startOfDay(for: $0.date) == lastDate }
            lastWorkoutCalories = lastDayWorkouts.compactMap(\.calories).reduce(0, +)
            lastWorkoutMinutes = lastDayWorkouts.reduce(0) { $0 + $1.duration / 60.0 }
        } else {
            lastWorkoutCalories = 0
            lastWorkoutMinutes = 0
        }

        activeDays = Set(recentWorkouts.map { calendar.startOfDay(for: $0.date) }).count
    }

    private let workoutService: WorkoutQuerying
    private let stepsService: StepsQuerying
    private let hrvService: HRVQuerying
    private let effortScoreService: EffortScoreService
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
        self.hrvService = HRVQueryService(manager: healthKitManager)
        self.effortScoreService = EffortScoreService(manager: healthKitManager)
        self.recommendationService = recommendationService ?? WorkoutRecommendationService()
        self.library = library ?? ExerciseLibraryService.shared
    }

    // MARK: - Workout Suggestion

    /// Cached SwiftData snapshots for merging with HealthKit data.
    private var exerciseRecordSnapshots: [ExerciseRecordSnapshot] = []

    func updateSuggestion(records: [ExerciseRecord]) {
        exerciseRecordSnapshots = records.map { record -> ExerciseRecordSnapshot in
            var primary = record.primaryMuscles
            var secondary = record.secondaryMuscles

            // Backfill muscles from library for V1-migrated records with empty muscle data
            if primary.isEmpty, let defID = record.exerciseDefinitionID,
               let definition = library.exercise(byID: defID) {
                primary = definition.primaryMuscles
                secondary = definition.secondaryMuscles
            }

            return ExerciseRecordSnapshot(
                date: record.date,
                exerciseDefinitionID: record.exerciseDefinitionID,
                primaryMuscles: primary,
                secondaryMuscles: secondary,
                completedSetCount: record.completedSets.count
            )
        }
        recomputeFatigueAndSuggestion()
    }

    /// Recompute fatigue states and suggestion from both SwiftData records and HealthKit workouts.
    private func recomputeFatigueAndSuggestion() {
        // Merge SwiftData exercise snapshots with HealthKit workout snapshots
        let healthKitSnapshots = recentWorkouts
            .filter { !$0.isFromThisApp }  // Avoid double-counting app-created workouts
            .filter { !$0.activityType.primaryMuscles.isEmpty }
            .map { workout in
                ExerciseRecordSnapshot(
                    date: workout.date,
                    exerciseDefinitionID: nil,
                    primaryMuscles: workout.activityType.primaryMuscles,
                    secondaryMuscles: workout.activityType.secondaryMuscles,
                    completedSetCount: 0
                )
            }

        let allSnapshots = exerciseRecordSnapshots + healthKitSnapshots
        fatigueStates = recommendationService.computeFatigueStates(from: allSnapshots)
        workoutSuggestion = recommendationService.recommend(from: allSnapshots, library: library)
    }

    private var loadTask: Task<Void, Never>?

    func loadActivityData() async {
        guard !isLoading else { return }
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        // 4 independent queries — parallel via async let
        async let exerciseTask = safeExerciseFetch()
        async let stepsTask = safeStepsFetch()
        async let workoutsTask = safeWorkoutsFetch()
        async let trainingLoadTask = safeTrainingLoadFetch()

        let (exerciseResult, stepsResult, workoutsResult, loadResult) = await (
            exerciseTask, stepsTask, workoutsTask, trainingLoadTask
        )

        guard !Task.isCancelled else { return }

        weeklyExerciseMinutes = exerciseResult.weeklyData
        todayExercise = exerciseResult.todayMetric
        weeklySteps = stepsResult.weeklyData
        todaySteps = stepsResult.todayMetric
        recentWorkouts = workoutsResult
        trainingLoadData = loadResult

        // Report partial failures (Correction #25)
        let failedCount = [
            exerciseResult.weeklyData.isEmpty && exerciseResult.todayMetric == nil,
            stepsResult.weeklyData.isEmpty && stepsResult.todayMetric == nil,
            workoutsResult.isEmpty,
            loadResult.isEmpty
        ].filter(\.self).count
        if failedCount > 0, failedCount < 4 {
            errorMessage = "일부 데이터를 불러올 수 없습니다 (\(failedCount)/4 소스)"
        } else if failedCount == 4 {
            errorMessage = "데이터를 불러올 수 없습니다. HealthKit 권한을 확인하세요."
        }

        // Recompute fatigue with newly fetched HealthKit workouts
        recomputeFatigueAndSuggestion()

        guard !Task.isCancelled else { return }
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

    // MARK: - Training Load (28-day)

    private func safeTrainingLoadFetch() async -> [TrainingLoadDataPoint] {
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let start = calendar.date(byAdding: .day, value: -27, to: today) else {
                return []
            }

            // Fetch workouts and resting HR in parallel
            async let workoutsTask = workoutService.fetchWorkouts(start: start, end: Date())
            async let rhrTask = hrvService.fetchLatestRestingHeartRate(withinDays: 30)

            let (workouts, rhrResult) = try await (workoutsTask, rhrTask)

            let restingHR = rhrResult?.value
            // Estimate max HR from 220-age formula; fallback to 190
            let maxHR: Double = 190

            // Group workouts by day
            var dailyWorkouts: [Date: [WorkoutSummary]] = [:]
            for workout in workouts {
                let dayStart = calendar.startOfDay(for: workout.date)
                dailyWorkouts[dayStart, default: []].append(workout)
            }

            // Build 28-day data
            var result: [TrainingLoadDataPoint] = []
            for dayOffset in (0..<28).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                let dayWorkouts = dailyWorkouts[dayStart] ?? []

                if dayWorkouts.isEmpty {
                    result.append(TrainingLoadDataPoint(date: dayStart, load: 0, source: nil))
                    continue
                }

                var dailyLoad = 0.0
                var bestSource: TrainingLoad.LoadSource?
                for workout in dayWorkouts {
                    let durationMinutes = workout.duration / 60.0
                    guard durationMinutes > 0, durationMinutes.isFinite else { continue }

                    if let source = TrainingLoadService.calculateLoad(
                        effortScore: workout.effortScore,
                        rpe: nil,
                        durationMinutes: durationMinutes,
                        heartRateAvg: workout.heartRateAvg,
                        restingHR: restingHR,
                        maxHR: maxHR
                    ) {
                        let load = TrainingLoadService.computeLoadValue(
                            source: source,
                            effortScore: workout.effortScore,
                            rpe: nil,
                            durationMinutes: durationMinutes,
                            heartRateAvg: workout.heartRateAvg,
                            restingHR: restingHR,
                            maxHR: maxHR
                        )
                        guard load.isFinite, !load.isNaN else { continue }
                        dailyLoad += load
                        bestSource = bestSource ?? source
                    }
                }

                result.append(TrainingLoadDataPoint(date: dayStart, load: dailyLoad, source: bestSource))
            }

            return result
        } catch {
            AppLogger.ui.error("Training load fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}
