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

    // New data for redesigned Activity tab
    var trainingReadiness: TrainingReadiness?

    // 14-day raw data for Training Readiness detail view
    var hrvDailyAverages: [DailySample] = []
    var rhrDailyData: [DailySample] = []
    var sleepDailyData: [SleepDailySample] = []
    var personalRecords: [StrengthPersonalRecord] = []
    var workoutStreak: WorkoutStreak?
    var exerciseFrequencies: [ExerciseFrequency] = []
    var weeklyStats: [ActivityStat] = []

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
    private let sleepService: SleepQuerying
    private let effortScoreService: EffortScoreService
    private let recommendationService: WorkoutRecommending
    private let recoveryModifierService: RecoveryModifying
    private let library: ExerciseLibraryQuerying
    private let readinessUseCase: TrainingReadinessCalculating
    private let sharedHealthDataService: SharedHealthDataService?

    /// Cached recovery modifiers from the most recent fetch.
    private var sleepModifier: Double = 1.0
    private var readinessModifier: Double = 1.0

    init(
        workoutService: WorkoutQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        healthKitManager: HealthKitManager = .shared,
        recommendationService: WorkoutRecommending? = nil,
        recoveryModifierService: RecoveryModifying = RecoveryModifierService(),
        library: ExerciseLibraryQuerying? = nil,
        readinessUseCase: TrainingReadinessCalculating = CalculateTrainingReadinessUseCase(),
        sharedHealthDataService: SharedHealthDataService? = nil
    ) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.effortScoreService = EffortScoreService(manager: healthKitManager)
        self.recommendationService = recommendationService ?? WorkoutRecommendationService()
        self.recoveryModifierService = recoveryModifierService
        self.library = library ?? ExerciseLibraryService.shared
        self.readinessUseCase = readinessUseCase
        self.sharedHealthDataService = sharedHealthDataService
    }

    // MARK: - Workout Suggestion

    /// Cached SwiftData snapshots for merging with HealthKit data.
    private var exerciseRecordSnapshots: [ExerciseRecordSnapshot] = []

    func updateSuggestion(records: [ExerciseRecord]) {
        exerciseRecordSnapshots = records.map { record -> ExerciseRecordSnapshot in
            var primary = record.primaryMuscles
            var secondary = record.secondaryMuscles

            // Backfill muscles from library for V1-migrated records with empty muscle data
            let definition: ExerciseDefinition?
            if primary.isEmpty, let defID = record.exerciseDefinitionID,
               let def = library.exercise(byID: defID) {
                primary = def.primaryMuscles
                secondary = def.secondaryMuscles
                definition = def
            } else {
                definition = record.exerciseDefinitionID.flatMap { library.exercise(byID: $0) }
            }

            let completedSets = record.completedSets
            let totalWeight = Swift.min(completedSets.compactMap(\.weight).reduce(0, +), 50_000)
            let totalReps = Swift.min(completedSets.compactMap(\.reps).reduce(0, +), 10_000)
            let durationMin = record.duration > 0 ? Swift.min(record.duration / 60.0, 480) : nil
            let distKm = record.distance.flatMap { $0 > 0 ? Swift.min($0 / 1000.0, 500) : nil }

            return ExerciseRecordSnapshot(
                date: record.date,
                exerciseDefinitionID: record.exerciseDefinitionID,
                exerciseName: definition?.name ?? record.exerciseType,
                primaryMuscles: primary,
                secondaryMuscles: secondary,
                completedSetCount: completedSets.count,
                totalWeight: totalWeight > 0 ? totalWeight : nil,
                totalReps: totalReps > 0 ? totalReps : nil,
                durationMinutes: durationMin,
                distanceKm: distKm
            )
        }
        recomputeFatigueAndSuggestion()
        recomputeDerivedStats()
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
                    exerciseName: workout.activityType.rawValue.capitalized,
                    primaryMuscles: workout.activityType.primaryMuscles,
                    secondaryMuscles: workout.activityType.secondaryMuscles,
                    completedSetCount: 0,
                    durationMinutes: workout.duration > 0 ? Swift.min(workout.duration / 60.0, 480) : nil,
                    distanceKm: workout.distance.flatMap { $0 > 0 ? Swift.min($0 / 1000.0, 500) : nil }
                )
            }

        let allSnapshots = exerciseRecordSnapshots + healthKitSnapshots
        fatigueStates = recommendationService.computeFatigueStates(
            from: allSnapshots,
            sleepModifier: sleepModifier,
            readinessModifier: readinessModifier
        )
        workoutSuggestion = recommendationService.recommend(from: allSnapshots, library: library)
    }

    /// Computes PR, Streak, and Frequency from current exercise record snapshots.
    func recomputeDerivedStats() {
        // Personal Records: extract max weight per exercise
        let prEntries = exerciseRecordSnapshots.compactMap { snapshot -> StrengthPRService.WorkoutEntry? in
            guard let name = snapshot.exerciseName, !name.isEmpty,
                  let weight = snapshot.totalWeight, weight > 0,
                  snapshot.completedSetCount > 0 else { return nil }
            return StrengthPRService.WorkoutEntry(
                exerciseName: name,
                date: snapshot.date,
                bestWeight: weight / Double(snapshot.completedSetCount)
            )
        }
        personalRecords = StrengthPRService.extractPRs(from: prEntries)

        // Workout Streak
        let streakEntries = exerciseRecordSnapshots.map { snapshot in
            WorkoutStreakService.WorkoutDay(
                date: snapshot.date,
                durationMinutes: snapshot.durationMinutes ?? 0
            )
        }
        // Also include HealthKit workouts
        let hkStreakEntries = recentWorkouts.map { workout in
            WorkoutStreakService.WorkoutDay(
                date: workout.date,
                durationMinutes: workout.duration / 60.0
            )
        }
        workoutStreak = WorkoutStreakService.calculate(from: streakEntries + hkStreakEntries)

        // Exercise Frequency
        let freqEntries = exerciseRecordSnapshots.compactMap { snapshot -> ExerciseFrequencyService.WorkoutEntry? in
            guard let name = snapshot.exerciseName, !name.isEmpty else { return nil }
            return ExerciseFrequencyService.WorkoutEntry(exerciseName: name, date: snapshot.date)
        }
        exerciseFrequencies = ExerciseFrequencyService.analyze(from: freqEntries)

        // Weekly Stats
        rebuildWeeklyStats()
    }

    private func rebuildWeeklyStats() {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeek = exerciseRecordSnapshots.filter { $0.date >= weekAgo }
        let prevWeekStart = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let prevWeek = exerciseRecordSnapshots.filter { $0.date >= prevWeekStart && $0.date < weekAgo }

        // Volume
        let totalVolume = thisWeek.compactMap(\.totalWeight).reduce(0, +)
        let prevVolume = prevWeek.compactMap(\.totalWeight).reduce(0, +)
        let rawVolumeChange = prevVolume > 0 ? ((totalVolume - prevVolume) / prevVolume * 100) : nil
        let volumeChange = rawVolumeChange.flatMap { $0.isFinite ? $0 : nil }

        // Duration
        let totalDuration = thisWeek.compactMap(\.durationMinutes).reduce(0, +)
        let prevDuration = prevWeek.compactMap(\.durationMinutes).reduce(0, +)
        let rawDurationChange = prevDuration > 0 ? ((totalDuration - prevDuration) / prevDuration * 100) : nil
        let durationChange = rawDurationChange.flatMap { $0.isFinite ? $0 : nil }

        // Calories from HealthKit workouts this week
        let hkThisWeek = recentWorkouts.filter { $0.date >= weekAgo }
        let totalCal = hkThisWeek.compactMap(\.calories).reduce(0, +)

        // Active days
        let activeDaySet = Set(
            (thisWeek.map { calendar.startOfDay(for: $0.date) })
            + (hkThisWeek.map { calendar.startOfDay(for: $0.date) })
        )

        weeklyStats = [
            .volume(
                value: totalVolume > 0 ? min(totalVolume, 50_000).formattedWithSeparator() : "—",
                change: volumeChange.map { "\($0.formattedWithSeparator(alwaysShowSign: true))%" },
                isPositive: volumeChange.map { $0 >= 0 }
            ),
            .calories(
                value: totalCal > 0 ? totalCal.formattedWithSeparator() : "—"
            ),
            .duration(
                value: totalDuration > 0 ? min(totalDuration, 28_800).formattedWithSeparator() : "—",
                change: durationChange.map { "\($0.formattedWithSeparator(alwaysShowSign: true))%" },
                isPositive: durationChange.map { $0 >= 0 }
            ),
            .activeDays(
                value: activeDaySet.count.formattedWithSeparator
            ),
        ]
    }

    private var loadTask: Task<Void, Never>?

    func loadActivityData() async {
        guard !isLoading else { return }
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        let sharedSnapshot = await sharedHealthDataService?.fetchSnapshot()

        // 7 independent queries — parallel via async let
        async let exerciseTask = safeExerciseFetch()
        async let stepsTask = safeStepsFetch()
        async let workoutsTask = safeWorkoutsFetch()
        async let trainingLoadTask = safeTrainingLoadFetch(snapshot: sharedSnapshot)
        async let sleepTask = safeSleepFetch(snapshot: sharedSnapshot)
        async let readinessTask = safeReadinessFetch(snapshot: sharedSnapshot)
        async let sleepDailyTask = safeSleepDailyFetch(snapshot: sharedSnapshot)

        let (exerciseResult, stepsResult, workoutsResult, loadResult, sleepResult, readinessResult, sleepDailyResult) = await (
            exerciseTask, stepsTask, workoutsTask, trainingLoadTask, sleepTask, readinessTask, sleepDailyTask
        )

        guard !Task.isCancelled else { return }

        weeklyExerciseMinutes = exerciseResult.weeklyData
        todayExercise = exerciseResult.todayMetric
        weeklySteps = stepsResult.weeklyData
        todaySteps = stepsResult.todayMetric
        recentWorkouts = workoutsResult
        trainingLoadData = loadResult

        // Compute recovery modifiers from sleep + HRV/RHR data
        sleepModifier = recoveryModifierService.calculateSleepModifier(
            totalSleepMinutes: sleepResult?.totalSleepMinutes,
            deepSleepRatio: sleepResult?.deepSleepRatio,
            remSleepRatio: sleepResult?.remSleepRatio
        )
        readinessModifier = recoveryModifierService.calculateReadinessModifier(
            hrvZScore: readinessResult.hrvZScore,
            rhrDelta: readinessResult.rhrDelta
        )

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

        // Recompute fatigue with newly fetched HealthKit workouts + recovery modifiers
        recomputeFatigueAndSuggestion()

        // Store 14-day raw data for Training Readiness detail
        hrvDailyAverages = computeHRVDailyAverages(from: readinessResult.hrvSamples)
        rhrDailyData = readinessResult.rhrCollection.map { DailySample(date: $0.date, value: $0.average) }
        sleepDailyData = sleepDailyResult

        // Compute Training Readiness Score
        let readinessInput = CalculateTrainingReadinessUseCase.Input(
            hrvSamples: readinessResult.hrvSamples,
            todayRHR: readinessResult.todayRHR,
            rhrBaseline: readinessResult.rhrBaseline,
            sleepDurationMinutes: sleepResult?.totalSleepMinutes,
            deepSleepRatio: sleepResult?.deepSleepRatio,
            remSleepRatio: sleepResult?.remSleepRatio,
            fatigueStates: fatigueStates
        )
        trainingReadiness = readinessUseCase.execute(input: readinessInput)

        // Compute derived stats (PRs, streak, frequency, weekly stats)
        recomputeDerivedStats()

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

    private func safeTrainingLoadFetch(snapshot: SharedHealthSnapshot?) async -> [TrainingLoadDataPoint] {
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let start = calendar.date(byAdding: .day, value: -27, to: today) else {
                return []
            }

            let workouts = try await workoutService.fetchWorkouts(start: start, end: Date())
            let restingHR: Double?
            if let snapshot {
                if let effectiveRHR = snapshot.effectiveRHR?.value {
                    restingHR = effectiveRHR
                } else {
                    // Keep the original 30-day fallback behavior for training load.
                    restingHR = try await hrvService.fetchLatestRestingHeartRate(withinDays: 30)?.value
                }
            } else {
                restingHR = try await hrvService.fetchLatestRestingHeartRate(withinDays: 30)?.value
            }
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

    // MARK: - Sleep Fetch (for recovery modifier)

    private func safeSleepFetch(snapshot: SharedHealthSnapshot?) async -> SleepSummary? {
        if let snapshot {
            return snapshot.sleepSummaryForRecovery
        }
        do {
            return try await sleepService.fetchLastNightSleepSummary(for: Date())
        } catch {
            AppLogger.ui.error("Sleep fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Sleep Daily Fetch (14-day)

    private func safeSleepDailyFetch(snapshot: SharedHealthSnapshot?) async -> [SleepDailySample] {
        if let snapshot {
            return snapshot.sleepDailyDurations
                .sorted { $0.date < $1.date }
                .suffix(14)
                .map {
                    SleepDailySample(
                        date: $0.date,
                        minutes: Swift.max(0, Swift.min($0.totalMinutes, 1440))
                    )
                }
        }
        do {
            let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            let results = try await sleepService.fetchDailySleepDurations(start: twoWeeksAgo, end: Date())
            return results.map { SleepDailySample(date: $0.date, minutes: Swift.max(0, Swift.min($0.totalMinutes, 1440))) }
        } catch {
            AppLogger.ui.error("Sleep daily fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - HRV Daily Averages

    private nonisolated func computeHRVDailyAverages(from samples: [HRVSample]) -> [DailySample] {
        let calendar = Calendar.current
        var dailyValues: [Date: [Double]] = [:]
        for sample in samples where sample.value > 0 && sample.value <= 500 && sample.value.isFinite {
            let day = calendar.startOfDay(for: sample.date)
            dailyValues[day, default: []].append(sample.value)
        }
        return dailyValues.map { DailySample(date: $0.key, value: $0.value.reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Readiness Fetch (HRV z-score + RHR delta)

    private struct ReadinessResult {
        let hrvZScore: Double?
        let rhrDelta: Double?
        let hrvSamples: [HRVSample]
        let todayRHR: Double?
        let rhrBaseline: [Double]
        let rhrCollection: [(date: Date, average: Double)]
    }

    private func safeReadinessFetch(snapshot: SharedHealthSnapshot?) async -> ReadinessResult {
        if let snapshot {
            let hrvSamples = snapshot.hrvSamples14Day
            let todayRHR = snapshot.todayRHR
            let yesterdayRHR = snapshot.yesterdayRHR

            let hrvZScore = computeHRVZScore(from: hrvSamples)

            let rhrDelta: Double?
            if let todayRHR, let yesterdayRHR,
               todayRHR > 0, todayRHR.isFinite, yesterdayRHR > 0, yesterdayRHR.isFinite {
                rhrDelta = todayRHR - yesterdayRHR
            } else {
                rhrDelta = nil
            }

            let validRHRCollection = snapshot.rhrCollection14Day
                .filter { $0.average > 0 && $0.average.isFinite && $0.average >= 20 && $0.average <= 300 }

            let rhrBaseline = validRHRCollection.map(\.average)

            return ReadinessResult(
                hrvZScore: hrvZScore,
                rhrDelta: rhrDelta,
                hrvSamples: hrvSamples,
                todayRHR: todayRHR,
                rhrBaseline: rhrBaseline,
                rhrCollection: validRHRCollection
            )
        }

        do {
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()

            // Fetch 14 days of HRV + today RHR + yesterday RHR + RHR collection in parallel
            async let hrvTask = hrvService.fetchHRVSamples(days: 14)
            async let todayRHRTask = hrvService.fetchRestingHeartRate(for: Date())
            async let yesterdayRHRTask = hrvService.fetchRestingHeartRate(for: yesterday)
            async let rhrCollectionTask = hrvService.fetchRHRCollection(
                start: twoWeeksAgo, end: Date(), interval: DateComponents(day: 1)
            )

            let (hrvSamples, todayRHR, yesterdayRHR, rhrCollection) = try await (
                hrvTask, todayRHRTask, yesterdayRHRTask, rhrCollectionTask
            )

            // Compute HRV z-score from daily averages (ln-domain)
            let hrvZScore = computeHRVZScore(from: hrvSamples)

            // RHR delta: today - yesterday (positive = elevated = worse)
            let rhrDelta: Double?
            if let today = todayRHR, let yesterday = yesterdayRHR,
               today > 0, today.isFinite, yesterday > 0, yesterday.isFinite {
                rhrDelta = today - yesterday
            } else {
                rhrDelta = nil
            }

            // RHR baseline: daily averages for training readiness
            let rhrBaseline = rhrCollection
                .map(\.average)
                .filter { $0 > 0 && $0.isFinite && $0 >= 20 && $0 <= 300 }

            let validRHRCollection = rhrCollection
                .filter { $0.average > 0 && $0.average.isFinite && $0.average >= 20 && $0.average <= 300 }
                .map { (date: $0.date, average: $0.average) }

            return ReadinessResult(
                hrvZScore: hrvZScore,
                rhrDelta: rhrDelta,
                hrvSamples: hrvSamples,
                todayRHR: todayRHR,
                rhrBaseline: rhrBaseline,
                rhrCollection: validRHRCollection
            )
        } catch {
            AppLogger.ui.error("Readiness fetch failed: \(error.localizedDescription)")
            return ReadinessResult(hrvZScore: nil, rhrDelta: nil, hrvSamples: [], todayRHR: nil, rhrBaseline: [], rhrCollection: [])
        }
    }

    /// Computes HRV z-score in ln-domain from recent samples.
    private nonisolated func computeHRVZScore(from samples: [HRVSample]) -> Double? {
        let calendar = Calendar.current

        // Group by day and compute daily averages
        var dailyValues: [Date: [Double]] = [:]
        for sample in samples where sample.value > 0 && sample.value <= 500 && sample.value.isFinite {
            let day = calendar.startOfDay(for: sample.date)
            dailyValues[day, default: []].append(sample.value)
        }

        let dailyAverages = dailyValues.map { (date: $0.key, value: $0.value.reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.date > $1.date }

        guard dailyAverages.count >= 7, let todayAverage = dailyAverages.first, todayAverage.value > 0 else {
            return nil
        }

        // ln-domain statistics
        let lnValues = dailyAverages.compactMap { $0.value > 0 ? log($0.value) : nil }
        guard lnValues.count >= 7 else { return nil }

        let mean = lnValues.reduce(0, +) / Double(lnValues.count)
        let variance = lnValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(lnValues.count)
        guard variance.isFinite, !variance.isNaN else { return nil }

        let stdDev = sqrt(variance)
        let normalRange = Swift.max(stdDev, 0.05)

        let todayLn = log(todayAverage.value)
        let zScore = (todayLn - mean) / normalRange
        guard zScore.isFinite, !zScore.isNaN else { return nil }

        return zScore
    }
}
