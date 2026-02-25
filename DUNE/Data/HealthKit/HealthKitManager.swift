import HealthKit
import OSLog

actor HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private let logger = AppLogger.healthKit

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
    ]

    /// Exposed for `HKWorkoutBuilder` which requires a store reference at init.
    var healthStore: HKHealthStore { store }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            logger.error("HealthKit not available on this device")
            throw HealthKitError.notAvailable
        }
        do {
            try await store.requestAuthorization(
                toShare: [
                    HKQuantityType(.activeEnergyBurned),
                    HKQuantityType.workoutType(),
                ],
                read: readTypes.union([HKObjectType.workoutType()])
            )
            logger.info("HealthKit authorization requested successfully")
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            throw error
        }
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
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
        } catch {
            logger.error("HK sample query failed: \(error.localizedDescription)")
            throw HealthKitError.queryFailed(error.localizedDescription)
        }
    }

    func executeStatistics(_ query: sending HKStatisticsQueryDescriptor) async throws -> HKStatistics? {
        do {
            return try await query.result(for: store)
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
        } catch {
            logger.error("HK statistics collection query failed: \(error.localizedDescription)")
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
