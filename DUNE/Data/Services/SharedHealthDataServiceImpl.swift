import Foundation

actor SharedHealthDataServiceImpl: SharedHealthDataService {
    private struct FetchResult<Value: Sendable>: Sendable {
        let value: Value
        let failed: Bool
    }

    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying
    private let conditionScoreUseCase: ConditionScoreCalculating
    private let cacheTTL: TimeInterval
    private let nowProvider: @Sendable () -> Date

    private var cachedSnapshot: SharedHealthSnapshot?
    private var cacheExpiresAt: Date?
    private var inFlightTask: Task<SharedHealthSnapshot, Never>?

    init(
        healthKitManager: HealthKitManager = .shared,
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        conditionScoreUseCase: ConditionScoreCalculating = CalculateConditionScoreUseCase(),
        cacheTTL: TimeInterval = 300,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.conditionScoreUseCase = conditionScoreUseCase
        self.cacheTTL = cacheTTL
        self.nowProvider = nowProvider
    }

    func fetchSnapshot() async -> SharedHealthSnapshot {
        let now = nowProvider()

        if let cachedSnapshot,
           let cacheExpiresAt,
           now < cacheExpiresAt {
            return cachedSnapshot
        }

        if let inFlightTask {
            return await inFlightTask.value
        }

        let task = Task { [self] in
            await buildSnapshot(referenceDate: now)
        }
        inFlightTask = task

        let snapshot = await task.value
        cachedSnapshot = snapshot
        cacheExpiresAt = nowProvider().addingTimeInterval(cacheTTL)
        inFlightTask = nil

        return snapshot
    }

    func invalidateCache() async {
        cachedSnapshot = nil
        cacheExpiresAt = nil
        inFlightTask = nil
    }

    private func buildSnapshot(referenceDate: Date) async -> SharedHealthSnapshot {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        let rhrCollectionStart = calendar.date(byAdding: .day, value: -60, to: referenceDate) ?? referenceDate

        let sleepDailyStart = calendar.date(byAdding: .day, value: -14, to: referenceDate) ?? referenceDate
        let sleepDailyEnd = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate

        async let hrvSamplesTask = fetch(
            source: .hrvSamples,
            defaultValue: [HRVSample]()
        ) {
            try await hrvService.fetchHRVSamples(days: 60)
        }

        async let todayRHRTask = fetch(
            source: .todayRHR,
            defaultValue: Optional<Double>.none
        ) {
            try await hrvService.fetchRestingHeartRate(for: referenceDate)
        }

        async let yesterdayRHRTask = fetch(
            source: .yesterdayRHR,
            defaultValue: Optional<Double>.none
        ) {
            try await hrvService.fetchRestingHeartRate(for: yesterday)
        }

        async let latestRHRTask = fetch(
            source: .latestRHR,
            defaultValue: Optional<(value: Double, date: Date)>.none
        ) {
            try await hrvService.fetchLatestRestingHeartRate(withinDays: 7)
        }

        async let rhrCollectionTask = fetch(
            source: .rhrCollection,
            defaultValue: [(date: Date, min: Double, max: Double, average: Double)]()
        ) {
            try await hrvService.fetchRHRCollection(
                start: rhrCollectionStart,
                end: referenceDate,
                interval: DateComponents(day: 1)
            )
        }

        async let todaySleepStagesTask = fetch(
            source: .todaySleepStages,
            defaultValue: [SleepStage]()
        ) {
            try await sleepService.fetchSleepStages(for: referenceDate)
        }

        async let yesterdaySleepStagesTask = fetch(
            source: .yesterdaySleepStages,
            defaultValue: [SleepStage]()
        ) {
            try await sleepService.fetchSleepStages(for: yesterday)
        }

        async let latestSleepStagesTask = fetch(
            source: .latestSleepStages,
            defaultValue: Optional<(stages: [SleepStage], date: Date)>.none
        ) {
            try await sleepService.fetchLatestSleepStages(withinDays: 7)
        }

        async let sleepDailyDurationsTask = fetch(
            source: .sleepDailyDurations,
            defaultValue: [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])]()
        ) {
            try await sleepService.fetchDailySleepDurations(start: sleepDailyStart, end: sleepDailyEnd)
        }

        let hrvSamplesResult = await hrvSamplesTask
        let todayRHRResult = await todayRHRTask
        let yesterdayRHRResult = await yesterdayRHRTask
        let latestRHRResult = await latestRHRTask
        let rhrCollectionResult = await rhrCollectionTask
        let todaySleepStagesResult = await todaySleepStagesTask
        let yesterdaySleepStagesResult = await yesterdaySleepStagesTask
        let latestSleepStagesResult = await latestSleepStagesTask
        let sleepDailyDurationsResult = await sleepDailyDurationsTask

        let conditionResult = computeCondition(
            hrvSamples: hrvSamplesResult.value,
            todayRHR: todayRHRResult.value,
            yesterdayRHR: yesterdayRHRResult.value,
            latestRHR: latestRHRResult.value,
            referenceDate: referenceDate
        )

        var failedSources: Set<SharedHealthSnapshot.Source> = []
        let failureInputs: [(SharedHealthSnapshot.Source, Bool)] = [
            (.hrvSamples, hrvSamplesResult.failed),
            (.todayRHR, todayRHRResult.failed),
            (.yesterdayRHR, yesterdayRHRResult.failed),
            (.latestRHR, latestRHRResult.failed),
            (.rhrCollection, rhrCollectionResult.failed),
            (.todaySleepStages, todaySleepStagesResult.failed),
            (.yesterdaySleepStages, yesterdaySleepStagesResult.failed),
            (.latestSleepStages, latestSleepStagesResult.failed),
            (.sleepDailyDurations, sleepDailyDurationsResult.failed)
        ]
        for (source, failed) in failureInputs where failed {
            failedSources.insert(source)
        }

        return SharedHealthSnapshot(
            hrvSamples: hrvSamplesResult.value,
            todayRHR: todayRHRResult.value,
            yesterdayRHR: yesterdayRHRResult.value,
            latestRHR: latestRHRResult.value.map {
                SharedHealthSnapshot.RHRSample(value: $0.value, date: $0.date)
            },
            rhrCollection: rhrCollectionResult.value,
            todaySleepStages: todaySleepStagesResult.value,
            yesterdaySleepStages: yesterdaySleepStagesResult.value,
            latestSleepStages: latestSleepStagesResult.value.map {
                SharedHealthSnapshot.SleepStagesSample(stages: $0.stages, date: $0.date)
            },
            sleepDailyDurations: sleepDailyDurationsResult.value.map {
                SharedHealthSnapshot.SleepDailyDuration(
                    date: $0.date,
                    totalMinutes: $0.totalMinutes,
                    stageBreakdown: $0.stageBreakdown
                )
            },
            conditionScore: conditionResult.score,
            baselineStatus: conditionResult.baselineStatus,
            recentConditionScores: conditionResult.recentScores,
            failedSources: failedSources,
            fetchedAt: referenceDate
        )
    }

    private func fetch<Value: Sendable>(
        source: SharedHealthSnapshot.Source,
        defaultValue: Value,
        operation: () async throws -> Value
    ) async -> FetchResult<Value> {
        do {
            return FetchResult(value: try await operation(), failed: false)
        } catch {
            AppLogger.ui.error("SharedHealthDataService \(source.rawValue) fetch failed: \(error.localizedDescription)")
            return FetchResult(value: defaultValue, failed: true)
        }
    }

    private func computeCondition(
        hrvSamples: [HRVSample],
        todayRHR: Double?,
        yesterdayRHR: Double?,
        latestRHR: (value: Double, date: Date)?,
        referenceDate: Date
    ) -> (score: ConditionScore?, baselineStatus: BaselineStatus?, recentScores: [ConditionScore]) {
        let calendar = Calendar.current
        let startOfRef = calendar.startOfDay(for: referenceDate)
        let conditionWindowStart = calendar.date(
            byAdding: .day,
            value: -CalculateConditionScoreUseCase.conditionWindowDays,
            to: startOfRef
        ) ?? startOfRef
        let conditionSamples = hrvSamples.filter { $0.date >= conditionWindowStart }

        // Only use actual today's RHR for condition change comparison.
        // Historical RHR fallback would compare non-adjacent days (Correction #24)
        let output = conditionScoreUseCase.execute(
            input: .init(
                hrvSamples: conditionSamples,
                todayRHR: todayRHR,
                yesterdayRHR: yesterdayRHR
            )
        )

        let recentScores = buildRecentScores(from: hrvSamples, referenceDate: referenceDate)

        return (score: output.score, baselineStatus: output.baselineStatus, recentScores: recentScores)
    }

    private func buildRecentScores(from samples: [HRVSample], referenceDate: Date) -> [ConditionScore] {
        let calendar = Calendar.current

        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else {
                return nil
            }

            let relevantSamples = samples.filter { $0.date < nextDay }
            let input = CalculateConditionScoreUseCase.Input(
                hrvSamples: relevantSamples,
                todayRHR: nil,
                yesterdayRHR: nil
            )
            guard let score = conditionScoreUseCase.execute(input: input).score else { return nil }

            return ConditionScore(
                score: score.score,
                date: calendar.startOfDay(for: date),
                contributions: score.contributions
            )
        }
    }
}
