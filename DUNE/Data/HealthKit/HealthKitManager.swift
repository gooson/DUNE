import Foundation
import HealthKit
import OSLog

protocol HealthKitManaging: Sendable {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    func saveMindfulSession(start: Date, end: Date) async throws
}

actor HealthKitManager: HealthKitManaging {
    static let shared = HealthKitManager()
    private static let persistedWindowKey = "healthkit.limitedReadAccessWindow.v1"
    private static let pendingConditionChangeKey = "healthkit.pendingConditionAccessChange.v1"

    private let store = HKHealthStore()
    private let logger = AppLogger.healthKit
    private var accessWindow: HealthDataAccessWindow
    private var hasPendingConditionAccessChange: Bool

    init() {
        hasPendingConditionAccessChange = UserDefaults.standard.bool(
            forKey: Self.pendingConditionChangeKey
        )
        if let saved = UserDefaults.standard.data(forKey: Self.persistedWindowKey),
           let window = try? JSONDecoder().decode(HealthDataAccessWindow.self, from: saved) {
            accessWindow = window
        } else {
            accessWindow = HealthDataAccessWindow()
        }
    }

    private let readTypes: Set<HKSampleType> = [
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRate),
        HKQuantityType(.stepCount),
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming),
        HKQuantityType(.runningSpeed),
        HKSeriesType.workoutRoute(),
        HKQuantityType(.bodyMass),
        HKQuantityType(.bodyFatPercentage),
        HKQuantityType(.leanBodyMass),
        HKQuantityType(.height),
        HKQuantityType(.bodyMassIndex),
        HKQuantityType(.workoutEffortScore),
        HKQuantityType(.estimatedWorkoutEffortScore),
        // Vitals (Wellness tab)
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.vo2Max),
        HKQuantityType(.heartRateRecoveryOneMinute),
        HKQuantityType(.appleSleepingWristTemperature),
        HKQuantityType(.appleSleepingBreathingDisturbances),
    ]

    /// Exposed for `HKWorkoutBuilder` which requires a store reference at init.
    var healthStore: HKHealthStore { store }

    nonisolated var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        try await requestAuthorization(
            toShare: [
                HKQuantityType(.activeEnergyBurned),
                HKQuantityType(.distanceWalkingRunning),
                HKQuantityType.workoutType(),
                HKSeriesType.workoutRoute(),
                HKCategoryType(.mindfulSession),
            ]
        )
    }

    func requestBodyCompositionWriteAuthorization() async throws {
        try await requestAuthorization(
            toShare: [
                HKQuantityType(.bodyMass),
                HKQuantityType(.bodyFatPercentage),
                HKQuantityType(.leanBodyMass),
            ]
        )
    }

    private func requestAuthorization(toShare shareTypes: Set<HKSampleType>) async throws {
        guard isAvailable else {
            logger.error("HealthKit not available on this device")
            throw HealthKitError.notAvailable
        }
        do {
            try await store.requestAuthorization(
                toShare: shareTypes,
                read: readTypes.union([HKObjectType.workoutType()])
            )
            _ = await refreshLimitedReadAccessWindow()
            logger.info("HealthKit authorization requested successfully")
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            throw error
        }
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    /// Recheck after authorization and when the app resumes from Health settings.
    /// A missing result is ambiguous and never means that read access was granted.
    @discardableResult
    func refreshLimitedReadAccessWindow() async -> Bool {
        let previous = accessWindow
        guard isAvailable else {
            accessWindow = HealthDataAccessWindow()
            return previous != accessWindow
        }
        do {
            let dates = try await store.earliestAuthorizedSampleDate(
                for: readTypes.union([HKObjectType.workoutType()])
            )
            accessWindow = HealthDataAccessWindow(
                limitedStartDates: Dictionary(
                    uniqueKeysWithValues: dates.map { ($0.key.identifier, $0.value) }
                )
            )
        } catch {
            // Preserve a known limited boundary until HealthKit can confirm a
            // replacement; a temporary error is not evidence of full access.
            logger.error("HealthKit read window unavailable: \(error.localizedDescription)")
            return false
        }
        let conditionTypes = [
            HKQuantityType(.heartRateVariabilitySDNN).identifier,
            HKQuantityType(.restingHeartRate).identifier
        ]
        let conditionChanged = accessWindow.changesConditionAccess(
            comparedTo: previous, for: conditionTypes
        )
        if conditionChanged {
            hasPendingConditionAccessChange = true
            UserDefaults.standard.set(true, forKey: Self.pendingConditionChangeKey)
        }
        if let saved = try? JSONEncoder().encode(accessWindow) {
            UserDefaults.standard.set(saved, forKey: Self.persistedWindowKey)
        }
        return previous != accessWindow
    }

    /// Authorization can refresh the window before the app's foreground path runs.
    /// Keep this durable until invalidation succeeds, including across a crash.
    func conditionAccessChangePending() -> Bool {
        hasPendingConditionAccessChange
    }

    func acknowledgeConditionAccessChange() {
        hasPendingConditionAccessChange = false
        UserDefaults.standard.set(false, forKey: Self.pendingConditionChangeKey)
    }

    func limitedReadStartDate(for type: HKObjectType) -> Date? {
#if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let limitedMetricTypes = [
            HKQuantityType(.heartRateVariabilitySDNN).identifier,
            HKQuantityType(.restingHeartRate).identifier
        ]
        if arguments.contains("--uitesting"),
           arguments.contains("--uitest-limited-health-history"),
           limitedMetricTypes.contains(type.identifier) {
            // Deterministic authorization window for simulator UI coverage.
            return Calendar.current.date(
                byAdding: .day,
                value: -2,
                to: Calendar.current.startOfDay(for: Date())
            )
        }
#endif
        return accessWindow.limitedStartDate(for: type.identifier)
    }

    func pointSampleQueryStart(for type: HKObjectType, intendedStart: Date) -> Date {
        accessWindow.pointSampleQueryStart(for: type.identifier, intendedStart: intendedStart)
    }

    /// No-op for read-only types. HealthKit's `authorizationStatus` only reflects
    /// **sharing (write)** permission. For read-only access, it always returns
    /// `.notDetermined` regardless of the user's actual choice (Apple privacy policy).
    /// Queries will simply return empty results if the user denied read access.
    func ensureNotDenied(for type: HKObjectType) throws {
        // This app only requests read access. authorizationStatus is unreliable
        // for read types, so we skip the check and let queries return empty data.
    }

    func execute<S: HKSample>(_ query: HKSampleQueryDescriptor<S>) async throws -> [S] {
        do {
            return try await query.result(for: store)
        } catch let error as HKError where error.code == .errorAuthorizationNotDetermined {
            logger.info("HK sample query skipped: authorization not yet requested")
            return []
        } catch {
            logger.error("HK sample query failed: \(error.localizedDescription)")
            throw HealthKitError.queryFailed(error.localizedDescription)
        }
    }

    func executeStatistics(_ query: sending HKStatisticsQueryDescriptor) async throws -> HKStatistics? {
        do {
            return try await query.result(for: store)
        } catch let error as HKError where error.code == .errorAuthorizationNotDetermined {
            logger.info("HK statistics query skipped: authorization not yet requested")
            return nil
        } catch {
            logger.error("HK statistics query failed: \(error.localizedDescription)")
            throw HealthKitError.queryFailed(error.localizedDescription)
        }
    }

    func executeStatisticsCollection(
        _ query: sending HKStatisticsCollectionQueryDescriptor
    ) async throws -> HKStatisticsCollection {
        do {
            return try await query.result(for: store)
        } catch let error as HKError where error.code == .errorAuthorizationNotDetermined {
            // HKStatisticsCollection has no public empty initializer, so we must rethrow.
            // Log at info (not error) since this is expected during deferred authorization.
            logger.info("HK statistics collection query deferred: authorization not yet requested")
            throw HealthKitError.queryFailed(error.localizedDescription)
        } catch {
            logger.error("HK statistics collection query failed: \(error.localizedDescription)")
            throw HealthKitError.queryFailed(error.localizedDescription)
        }
    }

    func saveMindfulSession(start: Date, end: Date) async throws {
        guard isAvailable else {
            logger.error("HealthKit not available while saving mindful session")
            throw HealthKitError.notAvailable
        }

        let resolvedEnd = max(end, start.addingTimeInterval(60))
        let sample = HKCategorySample(
            type: HKCategoryType(.mindfulSession),
            value: 0,
            start: start,
            end: resolvedEnd
        )

        do {
            try await store.save(sample)
            logger.info("Saved mindful session to HealthKit")
        } catch {
            logger.error("Saving mindful session failed: \(error.localizedDescription)")
            throw HealthKitError.queryFailed(error.localizedDescription)
        }
    }
}

enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case notAuthorized
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit authorization was not granted"
        case .queryFailed(let message):
            return "HealthKit query failed: \(message)"
        }
    }
}
