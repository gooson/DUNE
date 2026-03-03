import Foundation
import HealthKit

/// Bridges HealthKit observer callbacks to the notification system.
/// When an HKObserverQuery fires, fetches new samples via anchored query,
/// evaluates them for insights, and sends local notifications if criteria are met.
///
/// Designed for background execution (~30 second time limit).
final class BackgroundNotificationEvaluator: Sendable {

    private let store: HKHealthStore
    private let notificationService: NotificationService
    private let settingsStore: NotificationSettingsStore
    private let throttleStore: NotificationThrottleStore
    private let anchorStore: HealthKitAnchorStore

    init(
        store: HKHealthStore,
        notificationService: NotificationService,
        settingsStore: NotificationSettingsStore = .shared,
        throttleStore: NotificationThrottleStore = .shared,
        anchorStore: HealthKitAnchorStore = .shared
    ) {
        self.store = store
        self.notificationService = notificationService
        self.settingsStore = settingsStore
        self.throttleStore = throttleStore
        self.anchorStore = anchorStore
    }

    /// Called from HKObserverQuery callback. Fetches new samples and evaluates for notifications.
    func evaluateAndNotify(sampleType: HKSampleType) async {
        let insightType = mapToInsightType(sampleType)
        guard let insightType else { return }

        // Check user preference
        guard settingsStore.isEnabled(for: insightType) else { return }

        // Check throttle
        guard throttleStore.canSend(for: insightType) else { return }

        // Fetch new samples via anchored query
        let samples = await fetchNewSamples(for: sampleType)
        guard !samples.isEmpty else { return }

        // Evaluate and send
        let insight = evaluate(samples: samples, sampleType: sampleType, insightType: insightType)
        guard let insight else { return }

        throttleStore.recordSent(for: insightType)
        await notificationService.send(insight)
    }

    // MARK: - Anchored Query

    private func fetchNewSamples(for sampleType: HKSampleType) async -> [HKSample] {
        let anchor = anchorStore.anchor(for: sampleType)

        // Limit to today only to avoid processing old data on first launch
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: nil, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { [anchorStore] _, added, _, newAnchor, error in
                if let error {
                    AppLogger.notification.error("[BGEvaluator] Anchor query failed for \(sampleType.identifier): \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                if let newAnchor {
                    anchorStore.saveAnchor(newAnchor, for: sampleType)
                }

                continuation.resume(returning: added ?? [])
            }

            store.execute(query)
        }
    }

    // MARK: - Evaluation Dispatch

    private func evaluate(
        samples: [HKSample],
        sampleType: HKSampleType,
        insightType: HealthInsight.InsightType
    ) -> HealthInsight? {
        switch insightType {
        case .hrvAnomaly:
            return evaluateHRVSamples(samples)
        case .rhrAnomaly:
            return evaluateRHRSamples(samples)
        case .sleepComplete:
            return evaluateSleepSamples(samples)
        case .stepGoal:
            return evaluateStepSamples(samples)
        case .weightUpdate:
            return evaluateWeightSamples(samples)
        case .bodyFatUpdate:
            return evaluateBodyFatSamples(samples)
        case .bmiUpdate:
            return evaluateBMISamples(samples)
        case .workoutPR:
            return evaluateWorkoutSamples(samples)
        }
    }

    // MARK: - Type-specific Evaluation

    private func evaluateHRVSamples(_ samples: [HKSample]) -> HealthInsight? {
        guard let latest = samples.compactMap({ $0 as? HKQuantitySample }).last else { return nil }
        let value = latest.quantity.doubleValue(for: .secondUnit(with: .milli))
        guard value > 0, value <= 500 else { return nil }

        // Load cached baseline from UserDefaults (populated by foreground refresh)
        let baseline = loadCachedBaseline(for: .hrvAnomaly)
        guard !baseline.isEmpty else { return nil }

        return EvaluateHealthInsightUseCase.evaluateHRV(
            todayValue: value,
            recentDailyAverages: baseline
        )
    }

    private func evaluateRHRSamples(_ samples: [HKSample]) -> HealthInsight? {
        guard let latest = samples.compactMap({ $0 as? HKQuantitySample }).last else { return nil }
        let value = latest.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        guard value >= 20, value <= 300 else { return nil }

        let baseline = loadCachedBaseline(for: .rhrAnomaly)
        guard !baseline.isEmpty else { return nil }

        return EvaluateHealthInsightUseCase.evaluateRHR(
            todayValue: value,
            recentDailyAverages: baseline
        )
    }

    private func evaluateSleepSamples(_ samples: [HKSample]) -> HealthInsight? {
        let categorySamples = samples.compactMap { $0 as? HKCategorySample }
        // Accept inBed (iPhone) and all asleep stages (Watch) to detect sleep sessions.
        // Correction #110: Sleep stage classification consistency.
        let sleepSessionSamples = categorySamples.filter {
            let v = $0.value
            return v == HKCategoryValueSleepAnalysis.inBed.rawValue
                || v == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                || v == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                || v == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || v == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }
        guard let latest = sleepSessionSamples.last else { return nil }

        let totalMinutes = latest.endDate.timeIntervalSince(latest.startDate) / 60.0
        return EvaluateHealthInsightUseCase.evaluateSleepComplete(totalMinutes: totalMinutes)
    }

    private func evaluateStepSamples(_ samples: [HKSample]) -> HealthInsight? {
        // Sum all step samples for today
        let todayTotal = samples
            .compactMap { $0 as? HKQuantitySample }
            .reduce(0.0) { $0 + $1.quantity.doubleValue(for: .count()) }
        guard todayTotal > 0 else { return nil }

        // Need cumulative total — load cached value + new
        // Reset cache if day changed (prevents yesterday's total carrying over)
        let cached = loadCachedStepTotalIfToday()
        let total = cached + todayTotal

        // Persist running total for next background delivery
        Self.cacheStepTotal(total)

        return EvaluateHealthInsightUseCase.evaluateStepGoal(todaySteps: total)
    }

    private func evaluateWeightSamples(_ samples: [HKSample]) -> HealthInsight? {
        guard let latest = samples.compactMap({ $0 as? HKQuantitySample }).last else { return nil }
        let value = latest.quantity.doubleValue(for: .gramUnit(with: .kilo))
        let previous = loadCachedPreviousWeight()

        // Cache current weight for next delta comparison
        Self.cachePreviousWeight(value)

        return EvaluateHealthInsightUseCase.evaluateWeight(newValue: value, previousValue: previous)
    }

    private func evaluateBodyFatSamples(_ samples: [HKSample]) -> HealthInsight? {
        guard let latest = samples.compactMap({ $0 as? HKQuantitySample }).last else { return nil }
        let value = latest.quantity.doubleValue(for: .percent()) * 100.0
        return EvaluateHealthInsightUseCase.evaluateBodyFat(newValue: value)
    }

    private func evaluateBMISamples(_ samples: [HKSample]) -> HealthInsight? {
        guard let latest = samples.compactMap({ $0 as? HKQuantitySample }).last else { return nil }
        let value = latest.quantity.doubleValue(for: .count())
        return EvaluateHealthInsightUseCase.evaluateBMI(newValue: value)
    }

    private func evaluateWorkoutSamples(_ samples: [HKSample]) -> HealthInsight? {
        guard let workout = samples.compactMap({ $0 as? HKWorkout }).last else { return nil }

        let activityType = WorkoutActivityType(healthKit: workout.workoutActivityType)

        // Build minimal WorkoutSummary for PR detection
        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
        let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .meter())

        let summary = WorkoutSummary(
            id: workout.uuid.uuidString,
            type: activityType.typeName,
            activityType: activityType,
            duration: workout.duration,
            calories: calories,
            distance: distance,
            date: workout.startDate
        )

        let newPRTypes = PersonalRecordStore.shared.updateIfNewRecords(summary)
        guard !newPRTypes.isEmpty else { return nil }

        let typeNames = newPRTypes.map { prDisplayName(for: $0) }
        return EvaluateHealthInsightUseCase.evaluateWorkoutPR(
            activityName: activityType.typeName,
            recordTypeNames: typeNames
        )
    }

    // MARK: - PR Display Names (Data-layer safe, Foundation String(localized:))

    private func prDisplayName(for type: PersonalRecordType) -> String {
        switch type {
        case .fastestPace: String(localized: "Fastest Pace")
        case .longestDistance: String(localized: "Longest Distance")
        case .highestCalories: String(localized: "Highest Calories")
        case .longestDuration: String(localized: "Longest Duration")
        case .highestElevation: String(localized: "Highest Elevation")
        }
    }

    // MARK: - Type Mapping

    private func mapToInsightType(_ sampleType: HKSampleType) -> HealthInsight.InsightType? {
        switch sampleType {
        case HKQuantityType(.heartRateVariabilitySDNN): .hrvAnomaly
        case HKQuantityType(.restingHeartRate): .rhrAnomaly
        case HKCategoryType(.sleepAnalysis): .sleepComplete
        case HKQuantityType(.stepCount): .stepGoal
        case HKQuantityType(.bodyMass): .weightUpdate
        case HKQuantityType(.bodyFatPercentage): .bodyFatUpdate
        case HKQuantityType(.bodyMassIndex): .bmiUpdate
        case HKSampleType.workoutType(): .workoutPR
        default: nil  // HKSampleType is an open Apple framework type; exhaustive matching not possible
        }
    }

    // MARK: - Cached Baseline Access

    private enum CacheKeys {
        static let baselinePrefix = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".notificationBaseline."
        static let stepTotal = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".notificationStepTotal"
        static let stepTotalDate = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".notificationStepTotalDate"
        static let previousWeight = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".notificationPrevWeight"
    }

    /// Loads cached 7-day daily averages for HRV or RHR baseline comparison.
    /// Populated by `cacheBaseline(for:values:)` during foreground data loading.
    private func loadCachedBaseline(for type: HealthInsight.InsightType) -> [Double] {
        let key = CacheKeys.baselinePrefix + type.rawValue
        guard let data = UserDefaults.standard.data(forKey: key),
              let values = try? JSONDecoder().decode([Double].self, from: data) else {
            return []
        }
        return values
    }

    /// Caches baseline daily averages for background notification evaluation.
    /// Call from foreground data refresh path.
    static func cacheBaseline(for type: HealthInsight.InsightType, values: [Double]) {
        let key = CacheKeys.baselinePrefix + type.rawValue
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Caches today's cumulative step total for background evaluation.
    static func cacheStepTotal(_ total: Double) {
        UserDefaults.standard.set(total, forKey: CacheKeys.stepTotal)
        UserDefaults.standard.set(Date(), forKey: CacheKeys.stepTotalDate)
    }

    /// Loads cached step total only if it was saved today; returns 0 if stale.
    private func loadCachedStepTotalIfToday() -> Double {
        guard let savedDate = UserDefaults.standard.object(forKey: CacheKeys.stepTotalDate) as? Date,
              Calendar.current.isDateInToday(savedDate) else {
            return 0
        }
        return UserDefaults.standard.double(forKey: CacheKeys.stepTotal)
    }

    /// Caches the most recent weight for delta comparison.
    static func cachePreviousWeight(_ weight: Double) {
        UserDefaults.standard.set(weight, forKey: CacheKeys.previousWeight)
    }

    private func loadCachedPreviousWeight() -> Double? {
        let value = UserDefaults.standard.double(forKey: CacheKeys.previousWeight)
        return value > 0 ? value : nil
    }
}
