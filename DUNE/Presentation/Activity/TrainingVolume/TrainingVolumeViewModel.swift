import Foundation
import Observation
import OSLog

/// ViewModel for the comprehensive training volume analysis screen.
@Observable
@MainActor
final class TrainingVolumeViewModel {
    var selectedPeriod: VolumePeriod = .week {
        didSet { triggerReload() }
    }
    var comparison: PeriodComparison?
    var chartDailyBreakdown: [DailyVolumePoint] = []
    var trainingLoadData: [TrainingLoadDataPoint] = []
    var isLoading = false
    var errorMessage: String?

    let weeklyGoal: Int = 5

    private let workoutService: WorkoutQuerying
    private let stepsService: StepsQuerying
    private let hrvService: HRVQuerying
    private let effortScoreService: EffortScoreService
    init(
        workoutService: WorkoutQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        hrvService: HRVQuerying? = nil,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.effortScoreService = EffortScoreService(manager: healthKitManager)
    }

    // MARK: - Loading

    func loadData(manualRecords: [ExerciseRecord]) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Let the detail screen commit its first frame before the heavier
        // training-volume aggregation work starts on the main actor.
        await Task.yield()
        guard !Task.isCancelled else { return }

        let snapshots = manualRecords.map { record in
            ManualExerciseSnapshot(
                date: record.date,
                exerciseType: record.exerciseType,
                categoryRawValue: ActivityCategory.strength.rawValue,
                equipmentRawValue: record.resolvedEquipmentRaw,
                duration: record.duration,
                calories: record.estimatedCalories ?? record.calories ?? 0,
                totalVolume: record.totalVolume
            )
        }
        let manualLoadSnapshots = manualRecords.map(makeExerciseSnapshot)

        let period = selectedPeriod
        let fetchDays = period.days * 2 // Current + previous period
        let calendar = Calendar.current
        let historyEnd = Date()
        let historyEndDay = calendar.startOfDay(for: historyEnd)
        let historyStart = calendar.date(byAdding: .day, value: -(fetchDays - 1), to: historyEndDay) ?? historyEndDay
        let historySnapshots = snapshots.filter { $0.date >= historyStart && $0.date <= historyEnd }

        async let workoutsTask = safeWorkoutsFetch(days: fetchDays)
        async let trainingLoadTask = safeTrainingLoadFetch(
            historyDays: fetchDays,
            manualLoadSnapshots: manualLoadSnapshots
        )

        let (workouts, loadData) = await (workoutsTask, trainingLoadTask)

        guard !Task.isCancelled else { return }

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: workouts,
            manualRecords: snapshots,
            period: period
        )

        comparison = result
        chartDailyBreakdown = TrainingVolumeAnalysisService.buildHistoryDailyBreakdown(
            workouts: workouts,
            manualRecords: historySnapshots,
            start: historyStart,
            end: historyEnd
        )
        trainingLoadData = loadData

        guard !Task.isCancelled else { return }
    }

    // MARK: - Private

    private func triggerReload() {
        comparison = nil
        chartDailyBreakdown = []
        trainingLoadData = []
        // View will call loadData() via .task(id:)
    }

    private func safeWorkoutsFetch(days: Int) async -> [WorkoutSummary] {
        do {
            return try await workoutService.fetchWorkouts(days: days)
        } catch {
            AppLogger.ui.error("Volume workouts fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func safeTrainingLoadFetch(
        historyDays: Int,
        manualLoadSnapshots: [ExerciseRecordSnapshot]
    ) async -> [TrainingLoadDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard historyDays > 0,
              let start = calendar.date(byAdding: .day, value: -(historyDays - 1), to: today) else {
            return []
        }

        let workouts: [WorkoutSummary]
        do {
            workouts = try await workoutService.fetchWorkouts(start: start, end: Date())
        } catch {
            AppLogger.ui.error("Training load workout fetch failed: \(error.localizedDescription)")
            return buildManualTrainingLoadHistory(
                historyDays: historyDays,
                manualLoadSnapshots: manualLoadSnapshots
            )
        }

        let restingHR: Double?
        do {
            restingHR = try await hrvService.fetchLatestRestingHeartRate(withinDays: 30)?.value
        } catch {
            AppLogger.ui.error("Training load RHR fetch failed: \(error.localizedDescription)")
            restingHR = nil
        }

        if workouts.isEmpty {
            return buildManualTrainingLoadHistory(
                historyDays: historyDays,
                manualLoadSnapshots: manualLoadSnapshots
            )
        }

        return buildWorkoutTrainingLoadHistory(
            historyDays: historyDays,
            workouts: workouts,
            restingHR: restingHR
        )
    }

    private func buildWorkoutTrainingLoadHistory(
        historyDays: Int,
        workouts: [WorkoutSummary],
        restingHR: Double?
    ) -> [TrainingLoadDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let maxHR: Double = 190

        var dailyWorkouts: [Date: [WorkoutSummary]] = [:]
        for workout in workouts {
            let dayStart = calendar.startOfDay(for: workout.date)
            dailyWorkouts[dayStart, default: []].append(workout)
        }

        var result: [TrainingLoadDataPoint] = []
        for dayOffset in (0..<historyDays).reversed() {
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
    }

    private func buildManualTrainingLoadHistory(
        historyDays: Int,
        manualLoadSnapshots: [ExerciseRecordSnapshot]
    ) -> [TrainingLoadDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let fatigueService = FatigueCalculationService()

        var dailyLoads: [Date: Double] = [:]
        for snapshot in manualLoadSnapshots {
            let load = fatigueService.sessionLoad(from: snapshot)
            guard load.isFinite, !load.isNaN, load > 0 else { continue }
            let dayStart = calendar.startOfDay(for: snapshot.date)
            dailyLoads[dayStart, default: 0] += load
        }

        var result: [TrainingLoadDataPoint] = []
        for dayOffset in (0..<historyDays).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let load = dailyLoads[dayStart] ?? 0
            result.append(
                TrainingLoadDataPoint(
                    date: dayStart,
                    load: load,
                    source: load > 0 ? .rpe : nil
                )
            )
        }

        return result
    }

    private func makeExerciseSnapshot(from record: ExerciseRecord) -> ExerciseRecordSnapshot {
        let completedSets = record.completedSets
        let totalWeight = Swift.min(completedSets.compactMap(\.weight).reduce(0, +), 50_000)
        let totalReps = Swift.min(completedSets.compactMap(\.reps).reduce(0, +), 10_000)
        let durationMinutes = record.duration > 0 ? Swift.min(record.duration / 60.0, 480) : nil

        return ExerciseRecordSnapshot(
            date: record.date,
            exerciseDefinitionID: record.exerciseDefinitionID,
            exerciseName: record.exerciseType,
            primaryMuscles: record.primaryMuscles,
            secondaryMuscles: record.secondaryMuscles,
            completedSetCount: completedSets.count,
            totalWeight: totalWeight > 0 ? totalWeight : nil,
            totalReps: totalReps > 0 ? totalReps : nil,
            durationMinutes: durationMinutes,
            distanceKm: nil
        )
    }
}
