import SwiftUI

@Observable
@MainActor
final class DashboardViewModel {
    var conditionScore: ConditionScore?
    var baselineStatus: BaselineStatus?
    var metrics: [HealthMetric] = []
    var recentScores: [ConditionScore] = []
    var isLoading = false
    var errorMessage: String?

    private let hrvService = HRVQueryService()
    private let sleepService = SleepQueryService()
    private let workoutService = WorkoutQueryService()
    private let stepsService = StepsQueryService()
    private let scoreUseCase = CalculateConditionScoreUseCase()

    var sortedMetrics: [HealthMetric] {
        metrics.sorted { $0.changeSignificance > $1.changeSignificance }
    }

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

            metrics = allMetrics
        } catch {
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

        // Build 7-day score history
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
                date: Date(),
                category: .rhr
            ))
        }

        return metrics
    }

    private func fetchSleepData() async throws -> HealthMetric? {
        let stages = try await sleepService.fetchSleepStages(for: Date())
        guard !stages.isEmpty else { return nil }

        let totalMinutes = stages
            .filter { $0.stage != .awake }
            .map(\.duration)
            .reduce(0, +) / 60.0

        // Yesterday's sleep for comparison
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayStages = try await sleepService.fetchSleepStages(for: yesterday)
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
            date: Date(),
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
        guard let steps = try await stepsService.fetchSteps(for: Date()) else { return nil }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdaySteps = try await stepsService.fetchSteps(for: yesterday)
        let change: Double? = yesterdaySteps.map { steps - $0 }

        return HealthMetric(
            id: "steps",
            name: "Steps",
            value: steps,
            unit: "",
            change: change,
            date: Date(),
            category: .steps
        )
    }

    private func buildRecentScores(from samples: [HRVSample]) -> [ConditionScore] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }

        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { return nil }
            let day = calendar.startOfDay(for: date)
            guard let daySamples = grouped[day], !daySamples.isEmpty else { return nil }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let input = CalculateConditionScoreUseCase.Input(
                hrvSamples: samples.filter { $0.date <= nextDay },
                todayRHR: nil,
                yesterdayRHR: nil
            )
            let output = scoreUseCase.execute(input: input)
            return output.score.map { ConditionScore(score: $0.score, date: day) }
        }
    }
}
