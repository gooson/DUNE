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
    var focusInsight: CoachingInsight?
    private(set) var insightCards: [InsightCardData] = []
    var workoutSuggestion: WorkoutSuggestion?
    var recentHighRPEStreak: Int = 0
    var templateNudgeRecommendation: WorkoutTemplateRecommendation?
    var heroBaselineDetails: [BaselineDetail] = []
    private(set) var adaptiveHeroMessage: AdaptiveHeroMessage?

    // Phase 2: Yesterday Recap data
    private(set) var yesterdayWorkoutSummary: String?
    private(set) var yesterdaySleepMinutes: Double?
    private(set) var yesterdayConditionScore: Int?
    private(set) var todayWorkoutDone = false
    private(set) var shouldShowYesterdayRecap = false

    // Phase 2: Pre-computed metric values for progress rings (avoid repeated body lookups)
    private(set) var todayStepsValue: Double = 0
    private(set) var todaySleepMinutes: Double = 0

    // Phase 3: Cumulative stress + daily digest + time-aware ordering
    private(set) var cumulativeStressScore: CumulativeStressScore?
    private(set) var dailyDigest: DailyDigest?
    var pinnedCategories: [HealthMetric.Category]
    var baselineDeltasByMetricID: [String: MetricBaselineDelta] = [:]
    private(set) var sleepDeficitAnalysis: SleepDeficitAnalysis?
    private var hasLoadedOnce = false

    /// Assembled briefing data for the morning briefing sheet.
    private(set) var briefingData: MorningBriefingData?

    // Weather (Correction #8/#52: cached, not computed — accessed in SwiftUI body)
    private(set) var weatherSnapshot: WeatherSnapshot?
    private(set) var weatherAtmosphere: WeatherAtmosphere = .default

    /// Weather-category coaching insight for merging into WeatherCard (display-ready).
    var weatherCardInsight: WeatherCard.InsightInfo? {
        guard let insight = focusInsight, insight.category == .weather,
              weatherSnapshot != nil else { return nil }
        return WeatherCard.InsightInfo(title: insight.title, message: insight.message, iconName: insight.iconName)
    }

    /// Coaching insight that should render as standalone card (non-weather or no weather data).
    var standaloneCoachingInsight: CoachingInsight? {
        guard let insight = focusInsight else { return nil }
        return (insight.category == .weather && weatherSnapshot != nil) ? nil : insight
    }

    /// Sleep-category insight cards for RecoverySleepCard.
    private(set) var sleepInsightCards: [InsightCardData] = []

    /// Non-sleep insight cards for SmartInsightsSection.
    private(set) var nonSleepInsightCards: [InsightCardData] = []

    private(set) var pinnedMetrics: [HealthMetric] = []
    private(set) var activeDaysThisWeek = 0
    private(set) var isMirroredReadOnlyMode = false
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
        let arguments = ProcessInfo.processInfo.arguments
        let isRunningXCTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || arguments.contains("--uitesting")
        let isHealthKitPermissionUITest = arguments.contains("--healthkit-permission-uitest")
        return isRunningXCTest && !isHealthKitPermissionUITest
    }

    private static var shouldUseSeededUITestFixtures: Bool {
        ProcessInfo.processInfo.arguments.contains("--seed-mock")
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

    private func rebuildInsightPartitions() {
        sleepInsightCards = insightCards.filter { $0.category == .sleep }
        nonSleepInsightCards = insightCards.filter { $0.category != .sleep }
    }

    private let healthKitManager: HealthKitManager
    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying
    private let workoutService: WorkoutQuerying
    private let stepsService: StepsQuerying
    private let bodyService: BodyCompositionQuerying
    private let pinnedMetricsStore: TodayPinnedMetricsStore
    private let sharedHealthDataService: SharedHealthDataService?
    private let weatherProvider: WeatherProviding?
    private let scoreUseCase = CalculateConditionScoreUseCase()
    private let coachingEngine = CoachingEngine()
    private let coachingMessageEnhancer: (any CoachingMessageEnhancing)?
    private var enhanceCoachingTask: Task<Void, Never>?
    private var lastCoachingInput: CoachingInput?
    private let trendService = TrendAnalysisService()
    private let dismissStore = InsightCardDismissStore.shared
    private let scoreRefreshService: ScoreRefreshService?
    private let templateRecommendationService: any WorkoutTemplateRecommending
    private let nudgeDismissStore: TemplateNudgeDismissStore
    private var loadRequestID = 0

    /// Hourly sparkline data for the condition hero card.
    /// Stored (not computed read-through to ScoreRefreshService) to avoid cross-observable
    /// observation chain that causes NavigationStack layout feedback loops.
    private(set) var conditionSparkline: HourlySparklineData = .empty

    init(
        healthKitManager: HealthKitManager = .shared,
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        workoutService: WorkoutQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        bodyService: BodyCompositionQuerying? = nil,
        pinnedMetricsStore: TodayPinnedMetricsStore = .shared,
        sharedHealthDataService: SharedHealthDataService? = nil,
        weatherProvider: WeatherProviding? = nil,
        coachingMessageEnhancer: (any CoachingMessageEnhancing)? = AICoachingMessageService(),
        scoreRefreshService: ScoreRefreshService? = nil,
        templateRecommendationService: (any WorkoutTemplateRecommending)? = nil,
        nudgeDismissStore: TemplateNudgeDismissStore = .shared
    ) {
        self.healthKitManager = healthKitManager
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.bodyService = bodyService ?? BodyCompositionQueryService(manager: healthKitManager)
        self.pinnedMetricsStore = pinnedMetricsStore
        self.sharedHealthDataService = sharedHealthDataService
        // Create default weather provider if none injected (Correction: @MainActor init is safe for LocationService)
        self.weatherProvider = weatherProvider ?? WeatherProvider(locationService: LocationService())
        self.coachingMessageEnhancer = coachingMessageEnhancer
        self.scoreRefreshService = scoreRefreshService
        self.templateRecommendationService = templateRecommendationService ?? WorkoutTemplateRecommendationService()
        self.nudgeDismissStore = nudgeDismissStore
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

    func loadData(canLoadHealthKitData: Bool = true) async {
        let requestID = beginLoadRequest()
        isLoading = true
        defer { finishLoadRequest(requestID) }

        let healthKitAvailable = healthKitManager.isAvailable
        let canQueryMockBackedServices = Self.shouldUseSeededUITestFixtures
        let canQueryHealthKit = (healthKitAvailable || canQueryMockBackedServices) && canLoadHealthKitData
        let canUseSharedSnapshot = canQueryMockBackedServices || !healthKitAvailable || canLoadHealthKitData
        isMirroredReadOnlyMode = !healthKitAvailable && !canQueryMockBackedServices
        errorMessage = nil

        // Optimistic update: only reset state on first load (skeleton display).
        // On reload, keep existing data visible while fetching new data.
        if !hasLoadedOnce {
            conditionScore = nil
            baselineStatus = nil
            recentScores = []
            coachingMessage = nil
            focusInsight = nil
            insightCards = []
            rebuildInsightPartitions()
            heroBaselineDetails = []
            baselineDeltasByMetricID = [:]
            activeDaysThisWeek = 0
            weatherSnapshot = nil
            weatherAtmosphere = .default
        }

        if healthKitAvailable, !canLoadHealthKitData, !Self.shouldBypassAuthorizationForTests {
            AppLogger.ui.info("HealthKit authorization is deferred; skip protected dashboard queries until app-level orchestration completes")
        }

        async let weatherTask = safeWeatherFetch()
        let sharedSnapshot: SharedHealthSnapshot?
#if DEBUG
        if Self.shouldUseSeededUITestFixtures {
            sharedSnapshot = TestDataSeeder.sharedHealthSnapshot(for: UITestSeedScenario.current())
        } else if canUseSharedSnapshot {
            sharedSnapshot = await sharedHealthDataService?.fetchSnapshot()
        } else {
            sharedSnapshot = nil
        }
#else
        sharedSnapshot = canUseSharedSnapshot ? await sharedHealthDataService?.fetchSnapshot() : nil
#endif

        // Each fetch is independent — one failure should not block others.
        // All snapshot-aware fetches launch after snapshot is available.
        async let hrvTask = safeHRVFetch(snapshot: sharedSnapshot, canQueryHealthKit: canQueryHealthKit)
        async let sleepTask = safeSleepFetch(snapshot: sharedSnapshot, canQueryHealthKit: canQueryHealthKit)
        async let exerciseTask = safeExerciseFetch(snapshot: sharedSnapshot, canQueryHealthKit: canQueryHealthKit)
        async let stepsTask = safeStepsFetch(snapshot: sharedSnapshot, canQueryHealthKit: canQueryHealthKit)
        async let weightTask = safeWeightFetch(snapshot: sharedSnapshot, canQueryHealthKit: canQueryHealthKit)
        async let bmiTask = safeBMIFetch(snapshot: sharedSnapshot, canQueryHealthKit: canQueryHealthKit)

        let (hrvResult, sleepResult, exerciseResult, stepsResult, weightResult, bmiResult, weatherResult) = await (
            hrvTask, sleepTask, exerciseTask, stepsTask, weightTask, bmiTask, weatherTask
        )

        guard isCurrentLoadRequest(requestID) else { return }

        if hrvResult.failed, sharedSnapshot == nil {
            // Avoid showing stale readiness data after a live HRV refresh fails.
            conditionScore = nil
            baselineStatus = nil
            recentScores = []
            baselineDeltasByMetricID["hrv"] = nil
            baselineDeltasByMetricID["rhr"] = nil
        }

        var allMetrics: [HealthMetric] = []
        allMetrics.append(contentsOf: hrvResult.metrics)
        if let sleepMetric = sleepResult.metric { allMetrics.append(sleepMetric) }
        allMetrics.append(contentsOf: exerciseResult.metrics)
        if let stepsMetric = stepsResult.metric { allMetrics.append(stepsMetric) }
        if let weightMetric = weightResult.metric { allMetrics.append(weightMetric) }
        if let bmiMetric = bmiResult.metric { allMetrics.append(bmiMetric) }

        // Track partial failures
        let sourceFailures = [
            hrvResult.failed, sleepResult.failed, exerciseResult.failed,
            stepsResult.failed, weightResult.failed, bmiResult.failed
        ]
        let failureCount = sourceFailures.filter { $0 }.count
        let totalSources = sourceFailures.count

        if failureCount > 0 && !allMetrics.isEmpty {
            errorMessage = String(localized: "Some data could not be loaded (\(failureCount) of \(totalSources) sources)")
        } else if failureCount > 0 && allMetrics.isEmpty && !isMirroredReadOnlyMode {
            // On Mac (mirrored mode), empty data means CloudKit hasn't synced yet —
            // show CloudSyncWaitingView instead of an error.
            errorMessage = String(localized: "Failed to load health data")
        }

        weatherSnapshot = weatherResult
        weatherAtmosphere = weatherResult.map { WeatherAtmosphere.from($0) } ?? .default

        // Optimistic retention: on Mac mirrored mode, if reload yields empty metrics
        // but we already have data, keep existing metrics to prevent infinite spinner.
        if hasLoadedOnce && isMirroredReadOnlyMode && allMetrics.isEmpty && !self.sortedMetrics.isEmpty {
            AppLogger.ui.info("Optimistic retention: keeping \(self.sortedMetrics.count) existing metrics (reload returned empty)")
        } else {
            sortedMetrics = allMetrics.sorted { $0.changeSignificance > $1.changeSignificance }
        }
        buildCoachingInsights()
        coachingMessage = focusInsight?.message ?? buildCoachingMessage()
        enhanceCoachingMessageIfAvailable()
        heroBaselineDetails = buildHeroBaselineDetails()
        briefingData = buildBriefingData()
        buildAdaptiveHeroMessage()
        buildYesterdayRecap()
        buildCumulativeStressScore()
        buildDailyDigest()
        hasLoadedOnce = true
        lastUpdated = Date()
        WidgetDataWriter.writeConditionScore(conditionScore)

        // Persist hourly score snapshot for sparkline tracking
        if isCurrentLoadRequest(requestID), let service = scoreRefreshService, conditionScore != nil {
            await service.recordSnapshot(
                conditionScore: conditionScore?.score,
                wellnessScore: nil,
                readinessScore: nil
            )
            // Reload sparklines synchronously (bypasses the 200ms debounce in
            // scheduleSparklineReload) so the stored copy is up-to-date.
            await service.loadTodaySparklines()
        }

        syncSparklines()
    }

    /// Copy sparkline data from ScoreRefreshService into stored property.
    /// Breaks the cross-observable chain that causes NavigationStack layout feedback loops
    /// when ScoreRefreshService updates during navigation transitions.
    private func syncSparklines() {
        conditionSparkline = scoreRefreshService?.conditionSparkline ?? .empty
    }

    /// Load template nudge recommendation using existing templates from View's @Query.
    func loadTemplateNudge(existingTemplateSnapshots: [TemplateSnapshot]) async {
        guard !Self.shouldUseSeededUITestFixtures else {
            templateNudgeRecommendation = nil
            return
        }
        do {
            let workouts = try await workoutService.fetchWorkouts(days: 42)
            let recommendations = templateRecommendationService.recommendTemplates(
                from: workouts,
                config: .default,
                referenceDate: Date()
            )
            templateNudgeRecommendation = recommendations.first { rec in
                !TemplateOverlapChecker.isAlreadyCovered(
                    recommendation: rec,
                    existingTemplates: existingTemplateSnapshots
                ) && !nudgeDismissStore.isDismissed(rec.id)
            }
        } catch {
            AppLogger.ui.info("Template nudge load skipped: \(error.localizedDescription)")
            templateNudgeRecommendation = nil
        }
    }

    func dismissTemplateNudge() {
        guard let rec = templateNudgeRecommendation else { return }
        nudgeDismissStore.dismiss(rec.id)
        templateNudgeRecommendation = nil
    }

    private func beginLoadRequest() -> Int {
        loadRequestID += 1
        return loadRequestID
    }

    private func isCurrentLoadRequest(_ requestID: Int) -> Bool {
        requestID == loadRequestID && !Task.isCancelled
    }

    private func finishLoadRequest(_ requestID: Int) {
        if requestID == loadRequestID {
            isLoading = false
        }
    }

    private func safeHRVFetch(
        snapshot: SharedHealthSnapshot?,
        canQueryHealthKit: Bool
    ) async -> (metrics: [HealthMetric], failed: Bool) {
        if let snapshot {
            let hrvRelatedSources: Set<SharedHealthSnapshot.Source> = [
                .hrvSamples, .todayRHR, .yesterdayRHR, .latestRHR, .rhrCollection
            ]
            let metrics = fetchHRVData(from: snapshot)
            let failed = metrics.isEmpty && !snapshot.failedSources.isDisjoint(with: hrvRelatedSources)
            return (metrics, failed)
        }
        guard canQueryHealthKit else { return ([], false) }

        do { return (try await fetchHRVData(), false) }
        catch {
            AppLogger.ui.error("HRV fetch failed: \(error.localizedDescription)")
            return ([], true)
        }
    }

    private func safeSleepFetch(
        snapshot: SharedHealthSnapshot?,
        canQueryHealthKit: Bool
    ) async -> (metric: HealthMetric?, failed: Bool) {
        if let snapshot {
            let sleepRelatedSources: Set<SharedHealthSnapshot.Source> = [
                .todaySleepStages, .yesterdaySleepStages, .latestSleepStages, .sleepDailyDurations
            ]
            let metric = fetchSleepData(from: snapshot)
            let failed = metric == nil && !snapshot.failedSources.isDisjoint(with: sleepRelatedSources)
            return (metric, failed)
        }
        guard canQueryHealthKit else { return (nil, false) }

        do { return (try await fetchSleepData(), false) }
        catch {
            AppLogger.ui.error("Sleep fetch failed: \(error.localizedDescription)")
            return (nil, true)
        }
    }

    private func safeExerciseFetch(
        snapshot: SharedHealthSnapshot?,
        canQueryHealthKit: Bool
    ) async -> (metrics: [HealthMetric], failed: Bool) {
        // HealthKit first — provides rich per-type cards
        if canQueryHealthKit {
            do { return (try await fetchExerciseData(), false) }
            catch {
                AppLogger.ui.error("Exercise fetch failed: \(error.localizedDescription)")
                return ([], true)
            }
        }
        // Snapshot fallback (Mac / no-HealthKit environments)
        if let snapshot, let minutes = snapshot.todayExerciseMinutes, minutes > 0 {
            let metric = HealthMetric(
                id: "exercise",
                name: String(localized: "Exercise"),
                value: minutes,
                unit: "min",
                change: nil,
                date: snapshot.fetchedAt,
                category: .exercise
            )
            return ([metric], false)
        }
        if let snapshot, let recent = snapshot.recentExercise {
            let metric = HealthMetric(
                id: "exercise",
                name: String(localized: "Exercise"),
                value: recent.minutes,
                unit: "min",
                change: nil,
                date: recent.date,
                category: .exercise,
                isHistorical: recent.isHistorical
            )
            return ([metric], false)
        }
        if let snapshot, snapshot.failedSources.contains(.todayExercise) {
            return ([], true)
        }
        return ([], false)
    }

    private func safeStepsFetch(
        snapshot: SharedHealthSnapshot?,
        canQueryHealthKit: Bool
    ) async -> (metric: HealthMetric?, failed: Bool) {
        // HealthKit first
        if canQueryHealthKit {
            do { return (try await fetchStepsData(), false) }
            catch {
                AppLogger.ui.error("Steps fetch failed: \(error.localizedDescription)")
                return (nil, true)
            }
        }
        // Snapshot fallback (Mac / no-HealthKit environments)
        if let snapshot, let steps = snapshot.todaySteps, steps > 0, steps <= 200_000 {
            let metric = HealthMetric(
                id: "steps",
                name: String(localized: "Steps"),
                value: steps,
                unit: "",
                change: nil,
                date: snapshot.fetchedAt,
                category: .steps
            )
            return (metric, false)
        }
        if let snapshot, snapshot.failedSources.contains(.todaySteps) {
            return (nil, true)
        }
        return (nil, false)
    }

    private func safeWeightFetch(
        snapshot: SharedHealthSnapshot?,
        canQueryHealthKit: Bool
    ) async -> (metric: HealthMetric?, failed: Bool) {
        // HealthKit first
        if canQueryHealthKit {
            do { return (try await fetchWeightData(), false) }
            catch {
                AppLogger.ui.error("Weight fetch failed: \(error.localizedDescription)")
                return (nil, true)
            }
        }
        // Snapshot fallback (Mac / no-HealthKit environments)
        if let snapshot, let weight = snapshot.latestWeight,
           weight.value > 0, weight.value < 500 {
            let metric = HealthMetric(
                id: "weight",
                name: String(localized: "Weight"),
                value: weight.value,
                unit: "kg",
                change: nil,
                date: weight.date,
                category: .weight,
                isHistorical: !Calendar.current.isDateInToday(weight.date)
            )
            return (metric, false)
        }
        if let snapshot, snapshot.failedSources.contains(.latestWeight) {
            return (nil, true)
        }
        return (nil, false)
    }

    private func safeBMIFetch(
        snapshot: SharedHealthSnapshot?,
        canQueryHealthKit: Bool
    ) async -> (metric: HealthMetric?, failed: Bool) {
        // HealthKit first
        if canQueryHealthKit {
            do { return (try await fetchBMIData(), false) }
            catch {
                AppLogger.ui.error("BMI fetch failed: \(error.localizedDescription)")
                return (nil, true)
            }
        }
        // Snapshot fallback (Mac / no-HealthKit environments)
        if let snapshot, let bmi = snapshot.latestBMI,
           bmi.value > 0, bmi.value < 100 {
            let metric = HealthMetric(
                id: "bmi",
                name: String(localized: "BMI"),
                value: bmi.value,
                unit: "",
                change: nil,
                date: bmi.date,
                category: .bmi,
                isHistorical: !Calendar.current.isDateInToday(bmi.date)
            )
            return (metric, false)
        }
        if let snapshot, snapshot.failedSources.contains(.latestBMI) {
            return (nil, true)
        }
        return (nil, false)
    }

    /// Request location permission from user action (e.g. tapping weather placeholder).
    func requestLocationPermission() async {
        guard let weatherProvider else { return }
        await weatherProvider.requestLocationPermission()
        await waitForLocationPermissionResolution(using: weatherProvider)

        // Re-fetch weather after permission state resolves.
        let refreshedWeather = await safeWeatherFetch()
        weatherSnapshot = refreshedWeather
        weatherAtmosphere = refreshedWeather.map { WeatherAtmosphere.from($0) } ?? .default

        // Recompute coaching with refreshed weather context.
        buildCoachingInsights()
        coachingMessage = focusInsight?.message ?? buildCoachingMessage()
        enhanceCoachingMessageIfAvailable()
    }

    private func safeWeatherFetch() async -> WeatherSnapshot? {
#if DEBUG
        if Self.shouldUseSeededUITestFixtures {
            return TestDataSeeder.weatherSnapshot(for: UITestSeedScenario.current())
        }
#endif
        guard let weatherProvider else { return nil }
        do {
            return try await weatherProvider.fetchCurrentWeather()
        } catch {
            // Weather is non-critical — fail silently (graceful degradation)
            AppLogger.data.info("Weather fetch skipped: \(type(of: error)): \(error.localizedDescription)")
            return nil
        }
    }

    /// Wait until the location permission prompt is resolved (authorized or denied),
    /// then continue weather refresh. Prevents first-tap fetch before user selection.
    private func waitForLocationPermissionResolution(using weatherProvider: WeatherProviding) async {
        let timeoutSeconds: TimeInterval = 30
        let pollIntervalNanoseconds: UInt64 = 200_000_000
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            if await weatherProvider.isLocationPermissionDetermined {
                return
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
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
            rhrDailyAverages: makeRHRDailyAverages(from: rhrCollection),
            todayRHR: todayRHR,
            yesterdayRHR: yesterdayRHR,
            displayRHR: effectiveRHR,
            displayRHRDate: effectiveRHR != nil ? rhrDate : nil
        )
        let output = scoreUseCase.execute(input: input)
        conditionScore = output.score
        baselineStatus = output.baselineStatus

        // Build 7-day score history (use full samples for historical range)
        recentScores = buildRecentScores(from: samples, rhrCollection: rhrCollection)

        var metrics: [HealthMetric] = []

        // Latest HRV (samples are already 7 days, so first is the most recent)
        if let latest = samples.first {
            let isToday = calendar.isDateInToday(latest.date)
            let previousAvg = samples.dropFirst().prefix(7).map(\.value)
            let avgPrev = previousAvg.isEmpty ? nil : previousAvg.reduce(0, +) / Double(previousAvg.count)
            metrics.append(HealthMetric(
                id: "hrv",
                name: String(localized: "HRV"),
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
                name: String(localized: "RHR"),
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
                name: String(localized: "HRV"),
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
                name: String(localized: "RHR"),
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
    private let sleepDeficitUseCase = CalculateSleepDeficitUseCase()

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

        // Fetch 90 days for both baseline delta and deficit analysis
        let deficitStart = calendar.date(byAdding: .day, value: -90, to: today) ?? today
        let baselineEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dailySleep = try await sleepService.fetchDailySleepDurations(start: deficitStart, end: baselineEnd)

        // Baseline delta (existing: 14-day window, excluding current day)
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let recent14 = dailySleep.filter { $0.date >= fourteenDaysAgo }
        let baselineValues = recent14
            .filter { !calendar.isDate($0.date, inSameDayAs: sleepDate) }
            .map(\.totalMinutes)
        let shortTermAvg = average(baselineValues)
        let longTermValues = dailySleep.map(\.totalMinutes)
        let longTermAvg = average(longTermValues)
        baselineDeltasByMetricID["sleep"] = MetricBaselineDelta(
            yesterdayDelta: change,
            shortTermDelta: shortTermAvg.map { output.totalMinutes - $0 },
            longTermDelta: longTermAvg.map { output.totalMinutes - $0 }
        )

        // Deficit analysis
        sleepDeficitAnalysis = sleepDeficitUseCase.execute(input: .init(
            recentDurations: recent14.map(CalculateSleepDeficitUseCase.Input.DayDuration.init(from:)),
            longTermDurations: dailySleep.map(CalculateSleepDeficitUseCase.Input.DayDuration.init(from:))
        ))

        return HealthMetric(
            id: "sleep",
            name: String(localized: "Sleep"),
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

        let today = Date()
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let recent14 = snapshot.sleepDailyDurations.filter { $0.date >= fourteenDaysAgo }
        let baselineValues = recent14
            .filter { !calendar.isDate($0.date, inSameDayAs: sleepInput.date) }
            .map(\.totalMinutes)
        let shortTermAvg = average(baselineValues)
        let longTermValues = snapshot.sleepDailyDurations.map(\.totalMinutes)
        let longTermAvg = average(longTermValues)
        baselineDeltasByMetricID["sleep"] = MetricBaselineDelta(
            yesterdayDelta: change,
            shortTermDelta: shortTermAvg.map { output.totalMinutes - $0 },
            longTermDelta: longTermAvg.map { output.totalMinutes - $0 }
        )

        // Deficit analysis from snapshot data
        sleepDeficitAnalysis = sleepDeficitUseCase.execute(input: .init(
            recentDurations: recent14.map { .init(date: $0.date, totalMinutes: $0.totalMinutes) },
            longTermDurations: snapshot.sleepDailyDurations.map { .init(date: $0.date, totalMinutes: $0.totalMinutes) }
        ))

        return HealthMetric(
            id: "sleep",
            name: String(localized: "Sleep"),
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
                name: String(localized: "Exercise"),
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
            let latestDay = calendar.startOfDay(for: latest.date)
            let totalMinutes = minutesByDay[latestDay] ?? (latest.duration / 60.0)
            metrics.append(HealthMetric(
                id: "exercise",
                name: String(localized: "Exercise"),
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

        // Walking card (step-based): always include when walking workouts exist.
        if let walkingMetric = walkingStepsMetric(from: workouts) {
            metrics.append(walkingMetric)
        }

        // 2. Per-type cards from full 30-day range
        let grouped = Dictionary(grouping: workouts, by: \.type)

        var typeMetrics: [HealthMetric] = []
        for (type, typeWorkouts) in grouped {
            // Walking gets a dedicated step-based card above to avoid duplicate cards.
            if type.lowercased() == "walking" {
                continue
            }
            let todayOnes = typeWorkouts.filter { calendar.isDateInToday($0.date) }
            let relevantWorkouts = todayOnes.isEmpty
                ? [typeWorkouts.max(by: { $0.date < $1.date })].compactMap { $0 }
                : todayOnes
            let isToday = !todayOnes.isEmpty
            let latestDate = isToday ? Date() : (relevantWorkouts.first?.date ?? Date())

            let (value, unit) = Self.preferredMetric(for: type, workouts: relevantWorkouts)

            typeMetrics.append(HealthMetric(
                id: "exercise-\(type.lowercased())",
                name: relevantWorkouts.first?.localizedTitle
                    ?? relevantWorkouts.first?.activityType.displayName
                    ?? type,
                value: value,
                unit: unit,
                change: nil,
                date: latestDate,
                category: .exercise,
                isHistorical: !isToday,
                iconOverride: relevantWorkouts.first?.activityType.iconName ?? "figure.mixed.cardio",
                workoutTypeKey: type
            ))
        }

        typeMetrics.sort { $0.date > $1.date }
        metrics.append(contentsOf: typeMetrics)

        return metrics
    }

    /// Builds a dedicated walking card using step count as the primary value.
    /// Priority: latest workout steps -> day total -> week total -> 0 (still show card).
    private func walkingStepsMetric(from workouts: [WorkoutSummary]) -> HealthMetric? {
        let calendar = Calendar.current
        let walkingWorkouts = workouts
            .filter { $0.activityType == .walking }
            .sorted { $0.date > $1.date }

        guard let latestWalking = walkingWorkouts.first else { return nil }

        let latestWorkoutSteps = latestWalking.stepCount.flatMap { $0 > 0 ? $0 : nil }

        let dayStart = calendar.startOfDay(for: latestWalking.date)
        let dayTotal = walkingWorkouts
            .filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
            .compactMap(\.stepCount)
            .filter { $0 > 0 }
            .reduce(0, +)

        let weekTotal: Double = {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: latestWalking.date) else {
                return 0
            }
            return walkingWorkouts
                .filter { interval.contains($0.date) }
                .compactMap(\.stepCount)
                .filter { $0 > 0 }
                .reduce(0, +)
        }()

        let resolvedSteps = latestWorkoutSteps
            ?? (dayTotal > 0 ? dayTotal : nil)
            ?? (weekTotal > 0 ? weekTotal : nil)
            ?? 0

        return HealthMetric(
            id: "exercise-walking-steps",
            name: String(localized: "Walking"),
            value: resolvedSteps,
            unit: "steps",
            change: nil,
            date: latestWalking.date,
            category: .exercise,
            isHistorical: !calendar.isDateInToday(latestWalking.date),
            iconOverride: "figure.walk"
        )
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
                name: String(localized: "Steps"),
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
                name: String(localized: "Steps"),
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
            name: String(localized: "Weight"),
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
            name: String(localized: "BMI"),
            value: effectiveBMI,
            unit: "",
            change: change,
            date: bmiDate,
            category: .bmi,
            isHistorical: isHistorical
        )
    }

    /// Compute consecutive recent high-RPE sessions (RPE >= 8) from most recent backward.
    /// Sessions with nil RPE break the streak. Sessions older than 30 days are excluded
    /// to prevent stale data from inflating the streak.
    static func computeHighRPEStreak(from records: [ExerciseRecord]) -> Int {
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        let sorted = records.sorted { $0.date > $1.date }
        var streak = 0
        for record in sorted {
            guard record.date >= cutoff else { break }
            guard let rpe = record.rpe, rpe >= 8 else { break }
            streak += 1
        }
        return streak
    }

    func dismissInsightCard(id: String) {
        dismissStore.dismiss(cardID: id)
        insightCards.removeAll { $0.id == id }
        rebuildInsightPartitions()
    }

    private func buildCoachingInsights() {
        let sleepMetric = sortedMetrics.first { $0.category == .sleep }

        let input = CoachingInput(
            conditionScore: conditionScore,
            fatigueStates: [],
            sleepScore: nil,
            sleepMinutes: sleepMetric?.value,
            deepSleepMinutes: nil,
            workoutStreak: nil,
            hrvTrend: .insufficient,
            sleepTrend: .insufficient,
            activeDaysThisWeek: activeDaysThisWeek,
            weeklyGoalDays: weeklyGoalDays,
            daysSinceLastWorkout: nil,
            workoutSuggestion: workoutSuggestion,
            recentPRExerciseName: nil,
            currentStreakMilestone: nil,
            weather: weatherSnapshot,
            recentHighRPEStreak: recentHighRPEStreak
        )

        lastCoachingInput = input
        let output = coachingEngine.generate(from: input)
        focusInsight = output.focusInsight

        // Batch load dismissed IDs (single UserDefaults read) then filter
        let dismissed = dismissStore.dismissedIDs()
        insightCards = output.insightCards
            .filter { !dismissed.contains($0.id) }
            .map { InsightCardData(from: $0) }
        rebuildInsightPartitions()
    }

    private func enhanceCoachingMessageIfAvailable() {
        guard let enhancer = coachingMessageEnhancer,
              let insight = focusInsight,
              let input = lastCoachingInput else { return }

        enhanceCoachingTask?.cancel()
        let expectedInsightID = insight.id
        enhanceCoachingTask = Task {
            let enhanced = await enhancer.enhance(insight: insight, context: input)
            guard !Task.isCancelled,
                  focusInsight?.id == expectedInsightID else { return }
            focusInsight = enhanced
            coachingMessage = enhanced.message
        }
    }

    private func buildCoachingMessage() -> String {
        let remainingDays = max(0, weeklyGoalDays - activeDaysThisWeek)
        let sleepMinutes = sortedMetrics.first { $0.category == .sleep }?.value

        if let score = conditionScore {
            switch score.status {
            case .warning, .tired:
                return String(localized: "Recovery is low today. Choose low intensity and prioritize early sleep.")
            case .fair:
                if let sleepMinutes, sleepMinutes < 360 {
                    return String(localized: "Sleep was short. Keep today's training easy and protect recovery.")
                }
                return String(localized: "Keep the session moderate today and focus on consistency.")
            case .good, .excellent:
                if remainingDays > 0 {
                    return String(localized: "You're ready. Complete \(remainingDays) more active days this week.")
                }
                return String(localized: "Weekly goal achieved. Keep the momentum with quality movement.")
            }
        }

        if remainingDays > 0 {
            return String(localized: "No score yet. A short workout today helps maintain your weekly goal rhythm.")
        }
        return String(localized: "No score yet. Keep your routine steady and collect more recovery data.")
    }

    private func buildBriefingData() -> MorningBriefingData? {
        guard let score = conditionScore else { return nil }
        let detail = score.detail
        let sleepMetric = sortedMetrics.first { $0.category == .sleep }
        let hrvDelta = baselineDeltasByMetricID["hrv"]?.yesterdayDelta
        let rhrDelta = baselineDeltasByMetricID["rhr"]?.yesterdayDelta

        // Find recovery/training insights from coaching
        let recoveryInsight = insightCards.first { $0.category == .recovery }?.message
        let trainingInsight = insightCards.first { $0.category == .training }?.message

        // Sleep debt from deficit analysis
        let sleepDebtHours: Double? = {
            guard let deficit = sleepDeficitAnalysis, deficit.weeklyDeficit > 0 else { return nil }
            return deficit.weeklyDeficit / 60.0
        }()

        return MorningBriefingData(
            conditionScore: score.score,
            conditionStatus: score.status,
            hrvValue: detail?.todayHRV,
            hrvDelta: hrvDelta,
            rhrValue: detail?.displayRHR,
            rhrDelta: rhrDelta,
            sleepDurationMinutes: sleepMetric?.value,
            deepSleepMinutes: nil,
            sleepDeltaMinutes: nil,
            recoveryInsight: recoveryInsight,
            trainingInsight: trainingInsight,
            sleepDebtHours: sleepDebtHours,
            recentScores: recentScores.map { .init(date: $0.date, score: $0.score) },
            weeklyAverage: recentScores.isEmpty ? score.score : recentScores.map(\.score).reduce(0, +) / recentScores.count,
            previousWeekAverage: nil,
            activeDays: activeDaysThisWeek,
            goalDays: weeklyGoalDays,
            weatherCondition: weatherSnapshot?.condition.label,
            temperature: weatherSnapshot?.temperature,
            outdoorFitnessLevel: weatherSnapshot?.outdoorFitnessLevel.displayName,
            weatherInsight: focusInsight?.category == .weather ? focusInsight?.message : nil
        )
    }

    private func buildHeroBaselineDetails() -> [BaselineDetail] {
        var details: [BaselineDetail] = []
        if let hrvDetail = heroBaselineDetail(
            metricID: "hrv",
            shortLabel: String(localized: "HRV vs 14d avg"),
            longLabel: String(localized: "HRV vs 60d avg"),
            inversePolarity: false
        ) {
            details.append(hrvDetail)
        }
        if let rhrDetail = heroBaselineDetail(
            metricID: "rhr",
            shortLabel: String(localized: "RHR vs 14d avg"),
            longLabel: String(localized: "RHR vs 60d avg"),
            inversePolarity: true
        ) {
            details.append(rhrDetail)
        }
        return details
    }

    private func heroBaselineDetail(
        metricID: String,
        shortLabel: String,
        longLabel: String,
        inversePolarity: Bool
    ) -> BaselineDetail? {
        guard let delta = baselineDeltasByMetricID[metricID] else { return nil }
        if let short = delta.shortTermDelta {
            return BaselineDetail(
                label: shortLabel,
                value: short,
                fractionDigits: 0,
                inversePolarity: inversePolarity
            )
        }
        if let long = delta.longTermDelta {
            return BaselineDetail(
                label: longLabel,
                value: long,
                fractionDigits: 0,
                inversePolarity: inversePolarity
            )
        }
        return nil
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

    private func buildRecentScores(
        from samples: [HRVSample],
        rhrCollection: [(date: Date, min: Double, max: Double, average: Double)]
    ) -> [ConditionScore] {
        let calendar = Calendar.current
        let rhrDailyAverages = makeRHRDailyAverages(from: rhrCollection)

        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else {
                return nil
            }

            let relevantSamples = samples.filter { $0.date < nextDay }
            let relevantRHR = rhrDailyAverages.filter { $0.date < nextDay }
            let input = CalculateConditionScoreUseCase.Input(
                hrvSamples: relevantSamples,
                rhrDailyAverages: relevantRHR,
                todayRHR: nil,
                yesterdayRHR: nil
            )
            guard let score = scoreUseCase.execute(input: input).score else { return nil }
            return ConditionScore(score: score.score, date: calendar.startOfDay(for: date))
        }
    }

    private func makeRHRDailyAverages(
        from collection: [(date: Date, min: Double, max: Double, average: Double)]
    ) -> [CalculateConditionScoreUseCase.Input.RHRDailyAverage] {
        collection
            .filter { $0.average > 0 && $0.average.isFinite }
            .map { .init(date: $0.date, value: $0.average) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Adaptive Hero Message

    // MARK: - Time-Aware Dashboard (Phase 3)

    enum DashboardTimeBand: String, Sendable {
        case morning   // 06-10
        case daytime   // 10-17
        case evening   // 17-22
        case night     // 22-06

        static func from(hour: Int) -> DashboardTimeBand {
            switch hour {
            case 6..<10: .morning
            case 10..<17: .daytime
            case 17..<22: .evening
            default: .night
            }
        }
    }

    private(set) var currentTimeBand: DashboardTimeBand = .morning

    // Time-band visibility flags — stored to avoid observation feedback loops.
    // Computed properties reading currentTimeBand from body cause cascade invalidation
    // during NavigationStack transitions (Correction: .environment() @Observable rule).
    private(set) var shouldShowDailyDigest = false
    private(set) var shouldShowQuickActions = true
    private(set) var shouldShowProgressRings = true
    private(set) var shouldShowTodaysBrief = true
    private(set) var shouldShowExerciseIntelligence = true

    // MARK: - Cumulative Stress Score

    private let stressUseCase = CalculateCumulativeStressUseCase()

    private func buildCumulativeStressScore() {
        // Use HRV data already fetched for condition score
        guard conditionScore != nil else {
            cumulativeStressScore = nil
            return
        }
        // Build HRV daily averages from recent scores (we have 14-day window from condition)
        // For stress score we ideally want 30 days, but use what we have
        let dailyAverages = recentScores.compactMap { score -> CalculateCumulativeStressUseCase.Input.DailyAverage? in
            guard score.contributions.first(where: { $0.factor == .hrv }) != nil else { return nil }
            // Extract numeric value from detail string — use score as proxy
            return .init(date: score.date, value: Double(score.score))
        }

        // Sleep regularity from deficit analysis
        let sleepRegularity: SleepRegularityIndex?
        if let deficit = sleepDeficitAnalysis, deficit.dailyDeficits.count >= 3 {
            let dayCount = deficit.dailyDeficits.count
            let sleepValues = deficit.dailyDeficits.map(\.actualMinutes)
            let sleepMean = sleepValues.reduce(0, +) / Double(sleepValues.count)
            let sleepVariance = sleepValues.reduce(0.0) { $0 + ($1 - sleepMean) * ($1 - sleepMean) } / Double(sleepValues.count)
            let bedtimeStd = sqrt(sleepVariance)
            sleepRegularity = SleepRegularityIndex(
                score: max(0, min(100, Int((100.0 - bedtimeStd / 10.0).rounded()))),
                bedtimeStdDevMinutes: bedtimeStd,
                wakeTimeStdDevMinutes: bedtimeStd,
                averageBedtime: DateComponents(hour: 23, minute: 0),
                averageWakeTime: DateComponents(hour: 7, minute: 0),
                dataPointCount: dayCount,
                confidence: dayCount >= 14 ? .high : (dayCount >= 7 ? .medium : .low)
            )
        } else {
            sleepRegularity = nil
        }

        // Training load from exercise metric
        let exerciseMinutes = sortedMetrics.first { $0.category == .exercise }?.value ?? 0
        let trainingDurations: CalculateCumulativeStressUseCase.Input.WeeklyTrainingDurations?
        if exerciseMinutes > 0 {
            // Use today's exercise as acute estimate, condition score history as chronic proxy
            trainingDurations = .init(
                acuteMinutes: exerciseMinutes * 7, // extrapolate to weekly
                chronicWeeklyMinutes: max(exerciseMinutes * 7, 150) // fallback: 150 min/week
            )
        } else {
            trainingDurations = nil
        }

        let input = CalculateCumulativeStressUseCase.Input(
            hrvDailyAverages: dailyAverages,
            sleepRegularity: sleepRegularity,
            weeklyTrainingDurations: trainingDurations
        )

        cumulativeStressScore = stressUseCase.execute(input: input)
    }

    // MARK: - Daily Digest

    private let digestUseCase = GenerateDailyDigestUseCase()

    private func buildDailyDigest() {
        let hour = Calendar.current.component(.hour, from: Date())
        // Only generate after 17:00 (5 PM)
        guard hour >= 17 else {
            dailyDigest = nil
            shouldShowDailyDigest = false
            return
        }

        let metrics = DailyDigest.DigestMetrics(
            conditionScore: conditionScore?.score,
            conditionDelta: {
                guard let today = conditionScore?.score,
                      let yesterday = yesterdayConditionScore else { return nil }
                return today - yesterday
            }(),
            workoutSummary: todayWorkoutDone ? (yesterdayWorkoutSummary ?? String(localized: "workout")) : nil,
            sleepMinutes: todaySleepMinutes > 0 ? todaySleepMinutes : nil,
            sleepDebtMinutes: sleepDeficitAnalysis?.weeklyDeficit,
            stepsCount: todayStepsValue > 0 ? Int(todayStepsValue) : nil,
            stressLevel: cumulativeStressScore?.level
        )

        dailyDigest = digestUseCase.execute(metrics: metrics)
        shouldShowDailyDigest = dailyDigest != nil && (currentTimeBand == .evening || currentTimeBand == .night)
    }

    private func updateTimeBandVisibility() {
        let band = currentTimeBand
        shouldShowQuickActions = band != .night
        shouldShowProgressRings = band != .night
        shouldShowTodaysBrief = band == .morning || band == .daytime
        shouldShowExerciseIntelligence = band == .morning || band == .daytime
        // shouldShowDailyDigest depends on dailyDigest being non-nil — set after buildDailyDigest()
    }

    private func buildAdaptiveHeroMessage() {
        let hour = Calendar.current.component(.hour, from: Date())
        currentTimeBand = DashboardTimeBand.from(hour: hour)
        updateTimeBandVisibility()
        let exerciseMetric = sortedMetrics.first { $0.category == .exercise }
        let workoutDone = exerciseMetric != nil && (exerciseMetric?.value ?? 0) > 0
        todayWorkoutDone = workoutDone
        let sleepDebt = sleepDeficitAnalysis?.weeklyDeficit
        adaptiveHeroMessage = coachingEngine.generateAdaptiveHeroMessage(
            hour: hour,
            conditionScore: conditionScore,
            sleepDebtMinutes: sleepDebt,
            todayWorkoutDone: workoutDone
        )

        // Pre-compute metric values for progress rings (avoids repeated body lookups)
        todayStepsValue = sortedMetrics.first { $0.category == .steps }?.value ?? 0
        todaySleepMinutes = sortedMetrics.first { $0.category == .sleep }?.value ?? 0
    }

    // MARK: - Yesterday Recap

    private func buildYesterdayRecap() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
            shouldShowYesterdayRecap = false
            return
        }

        // Yesterday condition score from recentScores
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        yesterdayConditionScore = recentScores.first {
            calendar.isDate($0.date, inSameDayAs: yesterdayStart)
        }?.score

        // Yesterday sleep from deficit analysis daily data
        yesterdaySleepMinutes = sleepDeficitAnalysis?.dailyDeficits.first {
            calendar.isDate($0.date, inSameDayAs: yesterdayStart)
        }?.actualMinutes

        // Yesterday workout summary will be enriched from View's @Query
        yesterdayWorkoutSummary = nil

        // Pre-compute visibility (06-12 hours only)
        shouldShowYesterdayRecap = hour >= 6 && hour < 12
            && (yesterdayConditionScore != nil || yesterdaySleepMinutes != nil)
    }

    /// Enrich yesterday workout summary from exercise records (called from View).
    func updateYesterdayWorkoutSummary(from records: [ExerciseRecord]) {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return }
        let yesterdayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: yesterday) }
        guard !yesterdayRecords.isEmpty else {
            yesterdayWorkoutSummary = nil
            return
        }
        let totalSeconds = yesterdayRecords.map(\.duration).reduce(0, +)
        let totalMinutes = Int(totalSeconds / 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        let durationText = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        let count = yesterdayRecords.count
        yesterdayWorkoutSummary = "\(count) \(count == 1 ? String(localized: "exercise") : String(localized: "exercises")) · \(durationText)"
    }
}
