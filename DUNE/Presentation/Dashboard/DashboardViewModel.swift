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
    var coachingMessage: String?
    var heroBaselineDetails: [BaselineDetail] = []
    var pinnedCategories: [HealthMetric.Category]
    var baselineDeltasByMetricID: [String: MetricBaselineDelta] = [:]

    private(set) var pinnedMetrics: [HealthMetric] = []
    private(set) var activeDaysThisWeek = 0
    private let weeklyGoalDays = 5
    var weeklyGoalProgress: (completedDays: Int, goalDays: Int) {
        (completedDays: min(activeDaysThisWeek, weeklyGoalDays), goalDays: weeklyGoalDays)
    }
    var availablePinnedCategories: [HealthMetric.Category] {
        HealthMetric.Category.allCases.filter { TodayPinnedMetricsStore.allowedCategories.contains($0) }
    }

    // Cached filtered cards (VitalCardData for unified rendering)
    private(set) var pinnedCards: [VitalCardData] = []
    private(set) var conditionCards: [VitalCardData] = []
    private(set) var activityCards: [VitalCardData] = []
    private(set) var bodyCards: [VitalCardData] = []

    private static let conditionCategories: Set<HealthMetric.Category> = [.hrv, .rhr]
    private static let activityCardCategories: Set<HealthMetric.Category> = [.steps, .exercise]
    private static let bodyCategories: Set<HealthMetric.Category> = [.weight, .bmi, .sleep]
    private static var shouldBypassAuthorizationForTests: Bool {
        let isRunningXCTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let arguments = ProcessInfo.processInfo.arguments
        let isHealthKitPermissionUITest = arguments.contains("--healthkit-permission-uitest")
        return isRunningXCTest && !isHealthKitPermissionUITest
    }

    private func invalidateFilteredMetrics() {
        updatePinnedMetrics()
        let pinnedIDs = Set(pinnedMetrics.map(\.id))

        // Build VitalCardData arrays for unified rendering
        pinnedCards = pinnedMetrics.map { buildVitalCardData(from: $0) }

        let unpinned = sortedMetrics.filter { !pinnedIDs.contains($0.id) }
        conditionCards = unpinned
            .filter { Self.conditionCategories.contains($0.category) }
            .map { buildVitalCardData(from: $0) }
        activityCards = unpinned
            .filter { Self.activityCardCategories.contains($0.category) }
            .map { buildVitalCardData(from: $0) }
        bodyCards = unpinned
            .filter { Self.bodyCategories.contains($0.category) }
            .map { buildVitalCardData(from: $0) }
    }

    private let healthKitManager: HealthKitManager
    private var authorizationChecked = false
    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying
    private let workoutService: WorkoutQuerying
    private let stepsService: StepsQuerying
    private let bodyService: BodyCompositionQuerying
    private let pinnedMetricsStore: TodayPinnedMetricsStore
    private let sharedHealthDataService: SharedHealthDataService?
    private let scoreUseCase = CalculateConditionScoreUseCase()

    init(
        healthKitManager: HealthKitManager = .shared,
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        workoutService: WorkoutQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        bodyService: BodyCompositionQuerying? = nil,
        pinnedMetricsStore: TodayPinnedMetricsStore = .shared,
        sharedHealthDataService: SharedHealthDataService? = nil
    ) {
        self.healthKitManager = healthKitManager
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.bodyService = bodyService ?? BodyCompositionQueryService(manager: healthKitManager)
        self.pinnedMetricsStore = pinnedMetricsStore
        self.sharedHealthDataService = sharedHealthDataService
        self.pinnedCategories = pinnedMetricsStore.load()
    }

    func setPinnedCategories(_ categories: [HealthMetric.Category]) {
        pinnedMetricsStore.save(categories)
        pinnedCategories = pinnedMetricsStore.load()
        invalidateFilteredMetrics()
    }

    private func updatePinnedMetrics() {
        pinnedMetrics = pinnedCategories.compactMap { category in
            if category == .exercise {
                return sortedMetrics.first { $0.id == "exercise" }
            }
            return sortedMetrics.first { $0.category == category }
        }
    }

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        conditionScore = nil
        baselineStatus = nil
        recentScores = []
        coachingMessage = nil
        heroBaselineDetails = []
        baselineDeltasByMetricID = [:]
        activeDaysThisWeek = 0

        if !authorizationChecked {
            if Self.shouldBypassAuthorizationForTests {
                authorizationChecked = true
            } else {
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
        }

        let sharedSnapshot = await sharedHealthDataService?.fetchSnapshot()

        // Each fetch is independent — one failure should not block others (6 parallel)
        async let hrvTask = safeHRVFetch(snapshot: sharedSnapshot)
        async let sleepTask = safeSleepFetch(snapshot: sharedSnapshot)
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
        coachingMessage = buildCoachingMessage()
        heroBaselineDetails = buildHeroBaselineDetails()
        lastUpdated = Date()
        isLoading = false
    }

    private func safeHRVFetch(snapshot: SharedHealthSnapshot?) async -> (metrics: [HealthMetric], failed: Bool) {
        if let snapshot {
            let hrvRelatedSources: Set<SharedHealthSnapshot.Source> = [
                .hrvSamples, .todayRHR, .yesterdayRHR, .latestRHR, .rhrCollection
            ]
            let failed = !snapshot.failedSources.isDisjoint(with: hrvRelatedSources)
            return (fetchHRVData(from: snapshot), failed)
        }

        do { return (try await fetchHRVData(), false) }
        catch {
            AppLogger.ui.error("HRV fetch failed: \(error.localizedDescription)")
            return ([], true)
        }
    }

    private func safeSleepFetch(snapshot: SharedHealthSnapshot?) async -> (metric: HealthMetric?, failed: Bool) {
        if let snapshot {
            let sleepRelatedSources: Set<SharedHealthSnapshot.Source> = [
                .todaySleepStages, .yesterdaySleepStages, .latestSleepStages, .sleepDailyDurations
            ]
            let failed = !snapshot.failedSources.isDisjoint(with: sleepRelatedSources)
            return (fetchSleepData(from: snapshot), failed)
        }

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

        let rhrCollectionStart = calendar.date(byAdding: .day, value: -60, to: today) ?? today

        async let samplesTask = hrvService.fetchHRVSamples(days: 60)
        async let todayRHRTask = hrvService.fetchRestingHeartRate(for: today)
        async let yesterdayRHRTask = hrvService.fetchRestingHeartRate(for: yesterday)
        async let rhrCollectionTask = hrvService.fetchRHRCollection(
            start: rhrCollectionStart,
            end: today,
            interval: DateComponents(day: 1)
        )

        let (samples, todayRHR, yesterdayRHR, rhrCollection) = try await (
            samplesTask, todayRHRTask, yesterdayRHRTask, rhrCollectionTask
        )
        // Filter to condition window (matches shared snapshot path)
        let startOfToday = calendar.startOfDay(for: today)
        let conditionWindowStart = calendar.date(
            byAdding: .day,
            value: -CalculateConditionScoreUseCase.conditionWindowDays,
            to: startOfToday
        ) ?? startOfToday
        let conditionSamples = samples.filter { $0.date >= conditionWindowStart }

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

        // Only use actual today's RHR for condition change comparison.
        // Historical RHR fallback would compare non-adjacent days (Correction #24)
        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: conditionSamples,
            todayRHR: todayRHR,
            yesterdayRHR: yesterdayRHR
        )
        let output = scoreUseCase.execute(input: input)
        conditionScore = output.score
        baselineStatus = output.baselineStatus

        // Build 7-day score history (use full samples for historical range)
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

            let dailyHRV = dailyAveragesFromHRVSamples(samples)
            let yesterdayHRV = dailyHRV.first { calendar.isDateInYesterday($0.date) }?.value
            let shortTermAvg = average(dailyHRV.dropFirst().prefix(14).map(\.value))
            let longTermAvg = average(dailyHRV.dropFirst().prefix(60).map(\.value))
            baselineDeltasByMetricID["hrv"] = MetricBaselineDelta(
                yesterdayDelta: yesterdayHRV.map { latest.value - $0 },
                shortTermDelta: shortTermAvg.map { latest.value - $0 },
                longTermDelta: longTermAvg.map { latest.value - $0 }
            )
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

            let sortedCollection = rhrCollection
                .filter { $0.average > 0 && $0.average.isFinite }
                .sorted { $0.date > $1.date }
            let baselineSeries = sortedCollection
                .filter { !calendar.isDate($0.date, inSameDayAs: rhrDate) }
            let shortTermAvg = average(baselineSeries.prefix(14).map(\.average))
            let longTermAvg = average(baselineSeries.prefix(60).map(\.average))

            baselineDeltasByMetricID["rhr"] = MetricBaselineDelta(
                yesterdayDelta: yesterdayRHR.map { rhr - $0 },
                shortTermDelta: shortTermAvg.map { rhr - $0 },
                longTermDelta: longTermAvg.map { rhr - $0 }
            )
        }

        return metrics
    }

    private func fetchHRVData(from snapshot: SharedHealthSnapshot) -> [HealthMetric] {
        let calendar = Calendar.current

        conditionScore = snapshot.conditionScore
        baselineStatus = snapshot.baselineStatus
        recentScores = snapshot.recentConditionScores

        var metrics: [HealthMetric] = []
        let samples = snapshot.hrvSamples

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

            let dailyHRV = dailyAveragesFromHRVSamples(samples)
            let yesterdayHRV = dailyHRV.first { calendar.isDateInYesterday($0.date) }?.value
            let shortTermAvg = average(dailyHRV.dropFirst().prefix(14).map(\.value))
            let longTermAvg = average(dailyHRV.dropFirst().prefix(60).map(\.value))
            baselineDeltasByMetricID["hrv"] = MetricBaselineDelta(
                yesterdayDelta: yesterdayHRV.map { latest.value - $0 },
                shortTermDelta: shortTermAvg.map { latest.value - $0 },
                longTermDelta: longTermAvg.map { latest.value - $0 }
            )
        }

        if let effectiveRHR = snapshot.effectiveRHR {
            let rhr = effectiveRHR.value
            metrics.append(HealthMetric(
                id: "rhr",
                name: "RHR",
                value: rhr,
                unit: "bpm",
                change: snapshot.yesterdayRHR.map { rhr - $0 },
                date: effectiveRHR.date,
                category: .rhr,
                isHistorical: effectiveRHR.isHistorical
            ))

            let sortedCollection = snapshot.rhrCollection
                .filter { $0.average > 0 && $0.average.isFinite }
                .sorted { $0.date > $1.date }
            let baselineSeries = sortedCollection
                .filter { !calendar.isDate($0.date, inSameDayAs: effectiveRHR.date) }
            let shortTermAvg = average(baselineSeries.prefix(14).map(\.average))
            let longTermAvg = average(baselineSeries.prefix(60).map(\.average))

            baselineDeltasByMetricID["rhr"] = MetricBaselineDelta(
                yesterdayDelta: snapshot.yesterdayRHR.map { rhr - $0 },
                shortTermDelta: shortTermAvg.map { rhr - $0 },
                longTermDelta: longTermAvg.map { rhr - $0 }
            )
        }

        return metrics
    }

    private let sleepScoreUseCase = CalculateSleepScoreUseCase()

    private func fetchSleepData() async throws -> HealthMetric? {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

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

        let baselineStart = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let baselineEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dailySleep = try await sleepService.fetchDailySleepDurations(start: baselineStart, end: baselineEnd)
        let baselineValues = dailySleep
            .filter { !calendar.isDate($0.date, inSameDayAs: sleepDate) }
            .map(\.totalMinutes)
        let shortTermAvg = average(baselineValues)
        baselineDeltasByMetricID["sleep"] = MetricBaselineDelta(
            yesterdayDelta: change,
            shortTermDelta: shortTermAvg.map { output.totalMinutes - $0 },
            longTermDelta: nil
        )

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

    private func fetchSleepData(from snapshot: SharedHealthSnapshot) -> HealthMetric? {
        let calendar = Calendar.current
        guard let sleepInput = snapshot.sleepScoreInput else { return nil }

        let output = sleepScoreUseCase.execute(input: .init(stages: sleepInput.stages))
        let yesterdayOutput = sleepScoreUseCase.execute(input: .init(stages: snapshot.yesterdaySleepStages))

        let change: Double? = yesterdayOutput.totalMinutes > 0
            ? output.totalMinutes - yesterdayOutput.totalMinutes
            : nil

        let baselineValues = snapshot.sleepDailyDurations
            .filter { !calendar.isDate($0.date, inSameDayAs: sleepInput.date) }
            .map(\.totalMinutes)
        let shortTermAvg = average(baselineValues)
        baselineDeltasByMetricID["sleep"] = MetricBaselineDelta(
            yesterdayDelta: change,
            shortTermDelta: shortTermAvg.map { output.totalMinutes - $0 },
            longTermDelta: nil
        )

        return HealthMetric(
            id: "sleep",
            name: "Sleep",
            value: output.totalMinutes,
            unit: "min",
            change: change,
            date: sleepInput.date,
            category: .sleep,
            isHistorical: sleepInput.isHistorical
        )
    }

    private func fetchExerciseData() async throws -> [HealthMetric] {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        // 30 days for per-type cards (covers less frequent activities like cycling)
        let workouts = try await workoutService.fetchWorkouts(days: 30)
        guard !workouts.isEmpty else { return [] }

        let minutesByDay = Dictionary(grouping: workouts) {
            calendar.startOfDay(for: $0.date)
        }
        .mapValues { dayWorkouts in
            dayWorkouts.reduce(0.0) { $0 + $1.duration / 60.0 }
        }

        var metrics: [HealthMetric] = []

        // 1. Total Exercise card (today or most recent within 7 days)
        let recentWorkouts = workouts.filter {
            $0.date >= (calendar.date(byAdding: .day, value: -7, to: today) ?? today)
        }
        if let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today) {
            let thisWeekWorkouts = workouts.filter { currentWeek.contains($0.date) }
            activeDaysThisWeek = Set(thisWeekWorkouts.map { calendar.startOfDay(for: $0.date) }).count
        } else {
            activeDaysThisWeek = Set(recentWorkouts.map { calendar.startOfDay(for: $0.date) }).count
        }
        let todayWorkouts = recentWorkouts.filter { calendar.isDateInToday($0.date) }

        var currentExerciseValue: Double?
        var currentExerciseDate: Date?
        var isCurrentHistorical = false

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
            currentExerciseValue = totalMinutes
            currentExerciseDate = today
            isCurrentHistorical = false
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
            currentExerciseValue = totalMinutes
            currentExerciseDate = latest.date
            isCurrentHistorical = true
        }

        if let currentExerciseValue, let currentExerciseDate {
            let currentDay = calendar.startOfDay(for: currentExerciseDate)
            let baselineSeries = minutesByDay
                .filter { $0.key != currentDay }
                .sorted { $0.key > $1.key }
                .map(\.value)

            let yesterdayMinutes = minutesByDay[calendar.startOfDay(for: yesterday)]
            baselineDeltasByMetricID["exercise"] = MetricBaselineDelta(
                yesterdayDelta: (!isCurrentHistorical
                    ? yesterdayMinutes.map { currentExerciseValue - $0 }
                    : nil),
                shortTermDelta: average(baselineSeries.prefix(14)).map { currentExerciseValue - $0 },
                longTermDelta: average(baselineSeries.prefix(30)).map { currentExerciseValue - $0 }
            )
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
                iconOverride: relevantWorkouts.first?.activityType.iconName ?? "figure.mixed.cardio"
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
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let baselineStart = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let baselineEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        async let todayTask = stepsService.fetchSteps(for: today)
        async let yesterdayTask = stepsService.fetchSteps(for: yesterday)
        async let baselineTask = stepsService.fetchStepsCollection(
            start: baselineStart,
            end: baselineEnd,
            interval: DateComponents(day: 1)
        )

        let (todaySteps, yesterdaySteps, baselineCollection) = try await (todayTask, yesterdayTask, baselineTask)
        let baselineValues = baselineCollection
            .filter { !calendar.isDateInToday($0.date) }
            .map(\.sum)
        let shortTermAvg = average(baselineValues)

        if let steps = todaySteps {
            baselineDeltasByMetricID["steps"] = MetricBaselineDelta(
                yesterdayDelta: yesterdaySteps.map { steps - $0 },
                shortTermDelta: shortTermAvg.map { steps - $0 },
                longTermDelta: nil
            )
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
            baselineDeltasByMetricID["steps"] = MetricBaselineDelta(
                yesterdayDelta: nil,
                shortTermDelta: shortTermAvg.map { latest.value - $0 },
                longTermDelta: nil
            )
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

    private func buildCoachingMessage() -> String {
        let remainingDays = max(0, weeklyGoalDays - activeDaysThisWeek)
        let sleepMinutes = sortedMetrics.first { $0.category == .sleep }?.value

        if let score = conditionScore {
            switch score.status {
            case .warning, .tired:
                return "Recovery is low today. Choose low intensity and prioritize early sleep."
            case .fair:
                if let sleepMinutes, sleepMinutes < 360 {
                    return "Sleep was short. Keep today's training easy and protect recovery."
                }
                return "Keep the session moderate today and focus on consistency."
            case .good, .excellent:
                if remainingDays > 0 {
                    return "You're ready. Complete \(remainingDays) more active day\(remainingDays == 1 ? "" : "s") this week."
                }
                return "Weekly goal achieved. Keep the momentum with quality movement."
            }
        }

        if remainingDays > 0 {
            return "No score yet. A short workout today helps maintain your weekly goal rhythm."
        }
        return "No score yet. Keep your routine steady and collect more recovery data."
    }

    private func buildHeroBaselineDetails() -> [BaselineDetail] {
        guard let hrvDelta = baselineDeltasByMetricID["hrv"] else { return [] }
        var details: [BaselineDetail] = []
        if let yesterday = hrvDelta.yesterdayDelta {
            details.append(BaselineDetail(label: "HRV vs yesterday", value: yesterday, fractionDigits: 0))
        }
        if let short = hrvDelta.shortTermDelta {
            details.append(BaselineDetail(label: "HRV vs 14d avg", value: short, fractionDigits: 0))
        }
        return details
    }

    private func average<S: Sequence>(_ values: S) -> Double? where S.Element == Double {
        let array = Array(values)
        guard !array.isEmpty else { return nil }
        let sum = array.reduce(0, +)
        return sum / Double(array.count)
    }

    private func dailyAveragesFromHRVSamples(_ samples: [HRVSample]) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.date)
        }

        return grouped.compactMap { date, samples in
            let validValues = samples
                .map(\.value)
                .filter { $0 > 0 && $0.isFinite }
            guard let avg = average(validValues) else { return nil }
            return (date: date, value: avg)
        }
        .sorted { $0.date > $1.date }
    }

    // MARK: - VitalCardData Conversion

    private static let staleDays = 3

    private func buildVitalCardData(from metric: HealthMetric) -> VitalCardData {
        let daysSince = Calendar.current.dateComponents([.day], from: metric.date, to: Date()).day ?? 0
        let isStale = daysSince >= Self.staleDays
        let fractionDigits = metric.changeFractionDigits

        var changeStr: String?
        var changePositive: Bool?
        if let change = metric.change, !metric.isHistorical {
            let absChange = abs(change)
            if absChange >= 0.1 {
                changeStr = change.formattedWithSeparator(fractionDigits: fractionDigits, alwaysShowSign: true)
                changePositive = change > 0
            }
        }

        // Apply category-aware fraction digits to baseline detail
        let baseline: BaselineDetail?
        if let raw = baselineDeltasByMetricID[metric.id]?.preferredDetail {
            baseline = BaselineDetail(label: raw.label, value: raw.value, fractionDigits: fractionDigits)
        } else {
            baseline = nil
        }

        return VitalCardData(
            id: metric.id,
            category: metric.category,
            section: CardSection.section(for: metric.category),
            title: metric.name,
            value: metric.formattedNumericValue,
            unit: metric.resolvedUnitLabel,
            change: changeStr,
            changeIsPositive: changePositive,
            sparklineData: [],
            metric: metric,
            lastUpdated: metric.date,
            isStale: isStale,
            baselineDetail: baseline,
            inversePolarity: metric.category == .rhr
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
