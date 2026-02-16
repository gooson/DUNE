import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class DashboardViewModel {
    var conditionScore: ConditionScore?
    var baselineStatus: BaselineStatus?
    var sortedMetrics: [HealthMetric] = []
    var recentScores: [ConditionScore] = []
    var isLoading = false
    var errorMessage: String?

    private let healthKitManager: HealthKitManager
    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying
    private let workoutService: WorkoutQuerying
    private let stepsService: StepsQuerying
    private let scoreUseCase = CalculateConditionScoreUseCase()

    init(
        healthKitManager: HealthKitManager = .shared,
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        workoutService: WorkoutQuerying? = nil,
        stepsService: StepsQuerying? = nil
    ) {
        self.healthKitManager = healthKitManager
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
    }

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await healthKitManager.requestAuthorization()
        } catch {
            AppLogger.ui.error("HealthKit authorization failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        // Each fetch is independent — one failure should not block others
        async let hrvTask = safeHRVFetch()
        async let sleepTask = safeSleepFetch()
        async let exerciseTask = safeExerciseFetch()
        async let stepsTask = safeStepsFetch()

        let (hrvMetrics, sleepMetric, exerciseMetrics, stepsMetric) = await (
            hrvTask, sleepTask, exerciseTask, stepsTask
        )

        var allMetrics: [HealthMetric] = []
        allMetrics.append(contentsOf: hrvMetrics)
        if let sleepMetric { allMetrics.append(sleepMetric) }
        allMetrics.append(contentsOf: exerciseMetrics)
        if let stepsMetric { allMetrics.append(stepsMetric) }

        sortedMetrics = allMetrics.sorted { $0.changeSignificance > $1.changeSignificance }
        isLoading = false
    }

    private func safeHRVFetch() async -> [HealthMetric] {
        do { return try await fetchHRVData() }
        catch {
            AppLogger.ui.error("HRV fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func safeSleepFetch() async -> HealthMetric? {
        do { return try await fetchSleepData() }
        catch {
            AppLogger.ui.error("Sleep fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func safeExerciseFetch() async -> [HealthMetric] {
        do { return try await fetchExerciseData() }
        catch {
            AppLogger.ui.error("Exercise fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func safeStepsFetch() async -> HealthMetric? {
        do { return try await fetchStepsData() }
        catch {
            AppLogger.ui.error("Steps fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private

    private func fetchHRVData() async throws -> [HealthMetric] {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        async let samplesTask = hrvService.fetchHRVSamples(days: 7)
        async let todayRHRTask = hrvService.fetchRestingHeartRate(for: today)
        async let yesterdayRHRTask = hrvService.fetchRestingHeartRate(for: yesterday)

        let (samples, todayRHR, yesterdayRHR) = try await (samplesTask, todayRHRTask, yesterdayRHRTask)

        // Fallback RHR: if today is nil, use latest within 7 days for condition score
        let effectiveRHR: Double?
        let rhrDate: Date
        let rhrIsHistorical: Bool
        if let todayRHR {
            effectiveRHR = todayRHR
            rhrDate = today
            rhrIsHistorical = false
        } else if let latest = try await hrvService.fetchLatestRestingHeartRate(withinDays: 7) {
            effectiveRHR = latest.value
            rhrDate = latest.date
            rhrIsHistorical = true
        } else {
            effectiveRHR = nil
            rhrDate = today
            rhrIsHistorical = false
        }

        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: samples,
            todayRHR: effectiveRHR,
            yesterdayRHR: yesterdayRHR
        )
        let output = scoreUseCase.execute(input: input)
        conditionScore = output.score
        baselineStatus = output.baselineStatus

        // Build 7-day score history
        recentScores = buildRecentScores(from: samples)

        var metrics: [HealthMetric] = []

        // Latest HRV (samples are already 7 days, so first is the most recent)
        if let latest = samples.first {
            let isToday = calendar.isDateInToday(latest.date)
            let previousAvg = samples.dropFirst().prefix(7).map(\.value)
            let avgPrev = previousAvg.isEmpty ? nil : previousAvg.reduce(0, +) / Double(previousAvg.count)
            metrics.append(HealthMetric(
                id: "hrv",
                name: "HRV",
                value: latest.value,
                unit: "ms",
                change: avgPrev.map { latest.value - $0 },
                date: latest.date,
                category: .hrv,
                isHistorical: !isToday
            ))
        }

        // RHR (with fallback)
        if let rhr = effectiveRHR {
            metrics.append(HealthMetric(
                id: "rhr",
                name: "RHR",
                value: rhr,
                unit: "bpm",
                change: yesterdayRHR.map { rhr - $0 },
                date: rhrDate,
                category: .rhr,
                isHistorical: rhrIsHistorical
            ))
        }

        return metrics
    }

    private let sleepScoreUseCase = CalculateSleepScoreUseCase()

    private func fetchSleepData() async throws -> HealthMetric? {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today

        async let todayTask = sleepService.fetchSleepStages(for: today)
        async let yesterdayTask = sleepService.fetchSleepStages(for: yesterday)

        let (todayStages, yesterdayStages) = try await (todayTask, yesterdayTask)

        // Fallback: if today has no sleep data, find most recent within 7 days
        let stages: [SleepStage]
        let sleepDate: Date
        let isHistorical: Bool
        if !todayStages.isEmpty {
            stages = todayStages
            sleepDate = today
            isHistorical = false
        } else if let latest = try await sleepService.fetchLatestSleepStages(withinDays: 7) {
            stages = latest.stages
            sleepDate = latest.date
            isHistorical = true
        } else {
            return nil
        }

        let output = sleepScoreUseCase.execute(input: .init(stages: stages))
        let yesterdayOutput = sleepScoreUseCase.execute(input: .init(stages: yesterdayStages))

        let change: Double? = yesterdayOutput.totalMinutes > 0
            ? output.totalMinutes - yesterdayOutput.totalMinutes
            : nil

        return HealthMetric(
            id: "sleep",
            name: "Sleep",
            value: output.totalMinutes,
            unit: "min",
            change: change,
            date: sleepDate,
            category: .sleep,
            isHistorical: isHistorical
        )
    }

    private func fetchExerciseData() async throws -> [HealthMetric] {
        let calendar = Calendar.current

        // 30 days for per-type cards (covers less frequent activities like cycling)
        let workouts = try await workoutService.fetchWorkouts(days: 30)
        guard !workouts.isEmpty else { return [] }

        var metrics: [HealthMetric] = []

        // 1. Total Exercise card (today or most recent within 7 days)
        let recentWorkouts = workouts.filter {
            $0.date >= (calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date())
        }
        let todayWorkouts = recentWorkouts.filter { calendar.isDateInToday($0.date) }
        if !todayWorkouts.isEmpty {
            let totalMinutes = todayWorkouts.map(\.duration).reduce(0, +) / 60.0
            metrics.append(HealthMetric(
                id: "exercise",
                name: "Exercise",
                value: totalMinutes,
                unit: "min",
                change: nil,
                date: Date(),
                category: .exercise
            ))
        } else if let latest = recentWorkouts.first {
            let totalMinutes = latest.duration / 60.0
            metrics.append(HealthMetric(
                id: "exercise",
                name: "Exercise",
                value: totalMinutes,
                unit: "min",
                change: nil,
                date: latest.date,
                category: .exercise,
                isHistorical: true
            ))
        }

        // 2. Per-type cards from full 30-day range
        let grouped = Dictionary(grouping: workouts, by: \.type)

        var typeMetrics: [HealthMetric] = []
        for (type, typeWorkouts) in grouped {
            let todayOnes = typeWorkouts.filter { calendar.isDateInToday($0.date) }
            let relevantWorkouts = todayOnes.isEmpty
                ? [typeWorkouts.max(by: { $0.date < $1.date })].compactMap { $0 }
                : todayOnes
            let isToday = !todayOnes.isEmpty
            let latestDate = isToday ? Date() : (relevantWorkouts.first?.date ?? Date())

            let (value, unit) = Self.preferredMetric(for: type, workouts: relevantWorkouts)

            typeMetrics.append(HealthMetric(
                id: "exercise-\(type.lowercased())",
                name: type,
                value: value,
                unit: unit,
                change: nil,
                date: latestDate,
                category: .exercise,
                isHistorical: !isToday,
                iconOverride: Self.workoutIcon(type)
            ))
        }

        typeMetrics.sort { $0.date > $1.date }
        metrics.append(contentsOf: typeMetrics)

        return metrics
    }

    /// Returns the preferred display value and unit for a workout type.
    /// Distance-based types (running, cycling, walking, hiking, swimming) show distance.
    /// Swimming shows meters; others show km. Falls back to duration if no distance data.
    private static func preferredMetric(
        for type: String,
        workouts: [WorkoutSummary]
    ) -> (value: Double, unit: String) {
        let typeLower = type.lowercased()
        let totalMinutes = workouts.map(\.duration).reduce(0, +) / 60.0

        guard isDistanceBased(typeLower) else {
            return (totalMinutes, "min")
        }

        let totalMeters = workouts.compactMap(\.distance).reduce(0, +)
        guard totalMeters > 0 else {
            return (totalMinutes, "min")
        }

        if typeLower == "swimming" {
            return (totalMeters, "m")
        }
        return (totalMeters / 1000.0, "km")
    }

    /// Whether this workout type primarily measures distance.
    private static func isDistanceBased(_ type: String) -> Bool {
        switch type {
        case "running", "cycling", "walking", "hiking", "swimming":
            return true
        default:
            return false
        }
    }

    /// Maps workout type name to SF Symbol.
    private static func workoutIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "running":     "figure.run"
        case "walking":     "figure.walk"
        case "cycling":     "figure.outdoor.cycle"
        case "swimming":    "figure.pool.swim"
        case "hiking":      "figure.hiking"
        case "yoga":        "figure.yoga"
        case "strength", "strength training": "dumbbell.fill"
        case "dance", "dancing": "figure.dance"
        case "elliptical":  "figure.elliptical"
        case "rowing":      "figure.rower"
        case "stair stepper", "stairs": "figure.stairs"
        case "pilates":     "figure.pilates"
        case "martial arts": "figure.martial.arts"
        case "cooldown":    "figure.cooldown"
        case "core training": "figure.core.training"
        case "stretching", "flexibility": "figure.flexibility"
        default:            "figure.mixed.cardio"
        }
    }

    private func fetchStepsData() async throws -> HealthMetric? {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today

        async let todayTask = stepsService.fetchSteps(for: today)
        async let yesterdayTask = stepsService.fetchSteps(for: yesterday)

        let (todaySteps, yesterdaySteps) = try await (todayTask, yesterdayTask)

        if let steps = todaySteps {
            return HealthMetric(
                id: "steps",
                name: "Steps",
                value: steps,
                unit: "",
                change: yesterdaySteps.map { steps - $0 },
                date: today,
                category: .steps
            )
        }

        // Fallback: find most recent steps within 7 days
        if let latest = try await stepsService.fetchLatestSteps(withinDays: 7) {
            return HealthMetric(
                id: "steps",
                name: "Steps",
                value: latest.value,
                unit: "",
                change: nil,
                date: latest.date,
                category: .steps,
                isHistorical: true
            )
        }

        return nil
    }

    private func buildRecentScores(from samples: [HRVSample]) -> [ConditionScore] {
        let calendar = Calendar.current

        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else {
                return nil
            }

            let relevantSamples = samples.filter { $0.date < nextDay }
            let input = CalculateConditionScoreUseCase.Input(
                hrvSamples: relevantSamples,
                todayRHR: nil,
                yesterdayRHR: nil
            )
            guard let score = scoreUseCase.execute(input: input).score else { return nil }
            return ConditionScore(score: score.score, date: calendar.startOfDay(for: date))
        }
    }
}
