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
        healthKitManager: HealthKitManager = .shared
    ) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.hrvService = HRVQueryService(manager: healthKitManager)
        self.effortScoreService = EffortScoreService(manager: healthKitManager)
    }

    // MARK: - Loading

    func loadData(manualRecords: [ExerciseRecord]) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

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

        let period = selectedPeriod
        let fetchDays = period.days * 2 // Current + previous period

        async let workoutsTask = safeWorkoutsFetch(days: fetchDays)
        async let trainingLoadTask = safeTrainingLoadFetch()

        let (workouts, loadData) = await (workoutsTask, trainingLoadTask)

        guard !Task.isCancelled else { return }

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: workouts,
            manualRecords: snapshots,
            period: period
        )

        comparison = result
        trainingLoadData = loadData

        guard !Task.isCancelled else { return }
    }

    // MARK: - Private

    private func triggerReload() {
        comparison = nil
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

    private func safeTrainingLoadFetch() async -> [TrainingLoadDataPoint] {
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let start = calendar.date(byAdding: .day, value: -27, to: today) else {
                return []
            }

            async let workoutsTask = workoutService.fetchWorkouts(start: start, end: Date())
            async let rhrTask = hrvService.fetchLatestRestingHeartRate(withinDays: 30)

            let (workouts, rhrResult) = try await (workoutsTask, rhrTask)
            let restingHR = rhrResult?.value
            let maxHR: Double = 190

            var dailyWorkouts: [Date: [WorkoutSummary]] = [:]
            for workout in workouts {
                let dayStart = calendar.startOfDay(for: workout.date)
                dailyWorkouts[dayStart, default: []].append(workout)
            }

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
