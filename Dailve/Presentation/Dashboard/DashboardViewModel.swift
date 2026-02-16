import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class DashboardViewModel {
    var conditionScore: ConditionScore?
    var baselineStatus: BaselineStatus?
    var sortedMetrics: [HealthMetric] = [] {
        didSet { invalidateFilteredMetrics() }
    }
    var recentScores: [ConditionScore] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    // Cached filtered metrics (avoid recomputing in View body)
    private(set) var healthSignals: [HealthMetric] = []
    private(set) var activityMetrics: [HealthMetric] = []

    private static let healthCategories: Set<HealthMetric.Category> = [.hrv, .rhr, .weight, .bmi]

    private func invalidateFilteredMetrics() {
        healthSignals = sortedMetrics.filter { Self.healthCategories.contains($0.category) }
        activityMetrics = sortedMetrics.filter { !Self.healthCategories.contains($0.category) }
    }

    private let healthKitManager: HealthKitManager
    private var authorizationChecked = false
    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying
    private let workoutService: WorkoutQuerying
    private let stepsService: StepsQuerying
    private let bodyService: BodyCompositionQuerying
    private let scoreUseCase = CalculateConditionScoreUseCase()

    init(
        healthKitManager: HealthKitManager = .shared,
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        workoutService: WorkoutQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        bodyService: BodyCompositionQuerying? = nil
    ) {
        self.healthKitManager = healthKitManager
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.bodyService = bodyService ?? BodyCompositionQueryService(manager: healthKitManager)
    }

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        if !authorizationChecked {
            do {
                try await healthKitManager.requestAuthorization()
                authorizationChecked = true
            } catch {
                AppLogger.ui.error("HealthKit authorization failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                isLoading = false
                return
            }
        }

        // Each fetch is independent — one failure should not block others (6 parallel)
        async let hrvTask = safeHRVFetch()
        async let sleepTask = safeSleepFetch()
        async let exerciseTask = safeExerciseFetch()
        async let stepsTask = safeStepsFetch()
        async let weightTask = safeWeightFetch()
        async let bmiTask = safeBMIFetch()

        let (hrvResult, sleepResult, exerciseResult, stepsResult, weightResult, bmiResult) = await (
            hrvTask, sleepTask, exerciseTask, stepsTask, weightTask, bmiTask
        )

        var allMetrics: [HealthMetric] = []
        allMetrics.append(contentsOf: hrvResult.metrics)
        if let sleepMetric = sleepResult.metric { allMetrics.append(sleepMetric) }
        allMetrics.append(contentsOf: exerciseResult.metrics)
        if let stepsMetric = stepsResult.metric { allMetrics.append(stepsMetric) }
        if let weightMetric = weightResult.metric { allMetrics.append(weightMetric) }
        if let bmiMetric = bmiResult.metric { allMetrics.append(bmiMetric) }

        // Track partial failures
        let failureCount = [
            hrvResult.failed, sleepResult.failed, exerciseResult.failed,
            stepsResult.failed, weightResult.failed, bmiResult.failed
        ].filter { $0 }.count

        if failureCount > 0 && !allMetrics.isEmpty {
            errorMessage = "Some data could not be loaded (\(failureCount) of 6 sources)"
        } else if failureCount > 0 && allMetrics.isEmpty {
            errorMessage = "Failed to load health data"
        }

        sortedMetrics = allMetrics.sorted { $0.changeSignificance > $1.changeSignificance }
        lastUpdated = Date()
        isLoading = false
    }

    private func safeHRVFetch() async -> (metrics: [HealthMetric], failed: Bool) {
        do { return (try await fetchHRVData(), false) }
        catch {
            AppLogger.ui.error("HRV fetch failed: \(error.localizedDescription)")
            return ([], true)
        }
    }

    private func safeSleepFetch() async -> (metric: HealthMetric?, failed: Bool) {
        do { return (try await fetchSleepData(), false) }
        catch {
            AppLogger.ui.error("Sleep fetch failed: \(error.localizedDescription)")
            return (nil, true)
        }
    }

    private func safeExerciseFetch() async -> (metrics: [HealthMetric], failed: Bool) {
        do { return (try await fetchExerciseData(), false) }
        catch {
            AppLogger.ui.error("Exercise fetch failed: \(error.localizedDescription)")
            return ([], true)
        }
    }

    private func safeStepsFetch() async -> (metric: HealthMetric?, failed: Bool) {
        do { return (try await fetchStepsData(), false) }
        catch {
            AppLogger.ui.error("Steps fetch failed: \(error.localizedDescription)")
            return (nil, true)
        }
    }

    private func safeWeightFetch() async -> (metric: HealthMetric?, failed: Bool) {
        do { return (try await fetchWeightData(), false) }
        catch {
            AppLogger.ui.error("Weight fetch failed: \(error.localizedDescription)")
            return (nil, true)
        }
    }

    private func safeBMIFetch() async -> (metric: HealthMetric?, failed: Bool) {
        do { return (try await fetchBMIData(), false) }
        catch {
            AppLogger.ui.error("BMI fetch failed: \(error.localizedDescription)")
            return (nil, true)
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
                iconOverride: WorkoutSummary.iconName(for: type)
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

        guard WorkoutSummary.isDistanceBasedType(typeLower) else {
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

    // isDistanceBased and workoutIcon are now on WorkoutSummary (Domain layer)

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

    private func fetchWeightData() async throws -> HealthMetric? {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let todayStart = calendar.startOfDay(for: today)
        guard let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return nil }

        let todaySamples = try await bodyService.fetchWeight(start: todayStart, end: todayEnd)

        let effectiveWeight: Double
        let weightDate: Date
        let isHistorical: Bool
        if let latest = todaySamples.first, latest.value > 0, latest.value < 500 {
            effectiveWeight = latest.value
            weightDate = today
            isHistorical = false
        } else if let latest = try await bodyService.fetchLatestWeight(withinDays: 30),
                  latest.value > 0, latest.value < 500 {
            effectiveWeight = latest.value
            weightDate = latest.date
            isHistorical = true
        } else {
            return nil
        }

        // Change calculation only meaningful for today's data
        let change: Double?
        if !isHistorical {
            let yesterdayStart = calendar.startOfDay(for: yesterday)
            if let yesterdayEnd = calendar.date(byAdding: .day, value: 1, to: yesterdayStart) {
                let yesterdaySamples = try await bodyService.fetchWeight(start: yesterdayStart, end: yesterdayEnd)
                change = yesterdaySamples.first.map { effectiveWeight - $0.value }
            } else {
                change = nil
            }
        } else {
            change = nil
        }

        return HealthMetric(
            id: "weight",
            name: "Weight",
            value: effectiveWeight,
            unit: "kg",
            change: change,
            date: weightDate,
            category: .weight,
            isHistorical: isHistorical
        )
    }

    private func fetchBMIData() async throws -> HealthMetric? {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let effectiveBMI: Double
        let bmiDate: Date
        let isHistorical: Bool
        if let todayBMI = try await bodyService.fetchBMI(for: today), todayBMI > 0, todayBMI < 100 {
            effectiveBMI = todayBMI
            bmiDate = today
            isHistorical = false
        } else if let latest = try await bodyService.fetchLatestBMI(withinDays: 30),
                  latest.value > 0, latest.value < 100 {
            effectiveBMI = latest.value
            bmiDate = latest.date
            isHistorical = true
        } else {
            return nil
        }

        // Change calculation only meaningful for today's data
        let change: Double?
        if !isHistorical {
            let yesterdayBMI = try await bodyService.fetchBMI(for: yesterday)
            change = yesterdayBMI.map { effectiveBMI - $0 }
        } else {
            change = nil
        }

        return HealthMetric(
            id: "bmi",
            name: "BMI",
            value: effectiveBMI,
            unit: "",
            change: change,
            date: bmiDate,
            category: .bmi,
            isHistorical: isHistorical
        )
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
