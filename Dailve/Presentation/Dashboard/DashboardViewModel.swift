import SwiftUI
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

    private let hrvService = HRVQueryService()
    private let sleepService = SleepQueryService()
    private let workoutService = WorkoutQueryService()
    private let stepsService = StepsQueryService()
    private let scoreUseCase = CalculateConditionScoreUseCase()

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            try await HealthKitManager.shared.requestAuthorization()
            async let hrvTask = fetchHRVData()
            async let sleepTask = fetchSleepData()
            async let exerciseTask = fetchExerciseData()
            async let stepsTask = fetchStepsData()

            let (hrvMetrics, sleepMetric, exerciseMetric, stepsMetric) = await (
                try hrvTask, try sleepTask, try exerciseTask, try stepsTask
            )

            var allMetrics: [HealthMetric] = []
            allMetrics.append(contentsOf: hrvMetrics)
            if let sleepMetric { allMetrics.append(sleepMetric) }
            if let exerciseMetric { allMetrics.append(exerciseMetric) }
            if let stepsMetric { allMetrics.append(stepsMetric) }

            // Sort once at assignment time instead of on every access
            sortedMetrics = allMetrics.sorted { $0.changeSignificance > $1.changeSignificance }
        } catch {
            AppLogger.ui.error("Dashboard load failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private

    private func fetchHRVData() async throws -> [HealthMetric] {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today

        async let samplesTask = hrvService.fetchHRVSamples(days: 7)
        async let todayRHRTask = hrvService.fetchRestingHeartRate(for: today)
        async let yesterdayRHRTask = hrvService.fetchRestingHeartRate(for: yesterday)

        let (samples, todayRHR, yesterdayRHR) = try await (samplesTask, todayRHRTask, yesterdayRHRTask)

        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: samples,
            todayRHR: todayRHR,
            yesterdayRHR: yesterdayRHR
        )
        let output = scoreUseCase.execute(input: input)
        conditionScore = output.score
        baselineStatus = output.baselineStatus

        // Build 7-day score history — compute daily averages once, reuse
        recentScores = buildRecentScores(from: samples)

        var metrics: [HealthMetric] = []

        // Latest HRV
        if let latest = samples.first {
            let previousAvg = samples.dropFirst().prefix(7).map(\.value)
            let avgPrev = previousAvg.isEmpty ? nil : previousAvg.reduce(0, +) / Double(previousAvg.count)
            metrics.append(HealthMetric(
                id: "hrv",
                name: "HRV",
                value: latest.value,
                unit: "ms",
                change: avgPrev.map { latest.value - $0 },
                date: latest.date,
                category: .hrv
            ))
        }

        // RHR
        if let rhr = todayRHR {
            metrics.append(HealthMetric(
                id: "rhr",
                name: "RHR",
                value: rhr,
                unit: "bpm",
                change: yesterdayRHR.map { rhr - $0 },
                date: today,
                category: .rhr
            ))
        }

        return metrics
    }

    private func fetchSleepData() async throws -> HealthMetric? {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today

        async let todayTask = sleepService.fetchSleepStages(for: today)
        async let yesterdayTask = sleepService.fetchSleepStages(for: yesterday)

        let (stages, yesterdayStages) = try await (todayTask, yesterdayTask)
        guard !stages.isEmpty else { return nil }

        let totalMinutes = stages
            .filter { $0.stage != .awake }
            .map(\.duration)
            .reduce(0, +) / 60.0

        let yesterdayMinutes = yesterdayStages
            .filter { $0.stage != .awake }
            .map(\.duration)
            .reduce(0, +) / 60.0

        let change: Double? = yesterdayMinutes > 0 ? totalMinutes - yesterdayMinutes : nil

        return HealthMetric(
            id: "sleep",
            name: "Sleep",
            value: totalMinutes,
            unit: "min",
            change: change,
            date: today,
            category: .sleep
        )
    }

    private func fetchExerciseData() async throws -> HealthMetric? {
        let workouts = try await workoutService.fetchWorkouts(days: 1)
        guard !workouts.isEmpty else { return nil }

        let totalMinutes = workouts.map(\.duration).reduce(0, +) / 60.0

        return HealthMetric(
            id: "exercise",
            name: "Exercise",
            value: totalMinutes,
            unit: "min",
            change: nil,
            date: Date(),
            category: .exercise
        )
    }

    private func fetchStepsData() async throws -> HealthMetric? {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today

        async let todayTask = stepsService.fetchSteps(for: today)
        async let yesterdayTask = stepsService.fetchSteps(for: yesterday)

        let (steps, yesterdaySteps) = try await (todayTask, yesterdayTask)
        guard let steps else { return nil }

        let change: Double? = yesterdaySteps.map { steps - $0 }

        return HealthMetric(
            id: "steps",
            name: "Steps",
            value: steps,
            unit: "",
            change: change,
            date: today,
            category: .steps
        )
    }

    private func buildRecentScores(from samples: [HRVSample]) -> [ConditionScore] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }

        // Pre-compute daily averages once
        let dailyAverages: [(date: Date, value: Double)] = grouped.map { date, daySamples in
            let avg = daySamples.map(\.value).reduce(0, +) / Double(daySamples.count)
            return (date: date, value: avg)
        }.sorted { $0.date > $1.date }

        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { return nil }
            let day = calendar.startOfDay(for: date)
            guard grouped[day] != nil else { return nil }

            // Use pre-computed averages up to this day
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let relevantAverages = dailyAverages.filter { $0.date < nextDay }
            guard relevantAverages.count >= scoreUseCase.requiredDays else { return nil }

            guard let todayAvg = relevantAverages.first(where: { calendar.isDate($0.date, inSameDayAs: day) }),
                  todayAvg.value > 0 else { return nil }

            let validAverages = relevantAverages.filter { $0.value > 0 }
            let lnValues = validAverages.map { log($0.value) }
            let baseline = lnValues.reduce(0, +) / Double(lnValues.count)
            let todayLn = log(todayAvg.value)

            let variance = lnValues.map { ($0 - baseline) * ($0 - baseline) }
                .reduce(0, +) / Double(lnValues.count)
            guard !variance.isNaN && !variance.isInfinite else { return nil }

            let stdDev = sqrt(variance)
            let normalRange = max(stdDev, 0.05)
            let zScore = (todayLn - baseline) / normalRange
            let rawScore = 50.0 + (zScore * 25.0)
            let clampedScore = Int(max(0, min(100, rawScore)))

            return ConditionScore(score: clampedScore, date: day)
        }
    }
}
