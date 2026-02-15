import HealthKit
import OSLog

actor HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private let logger = AppLogger.healthKit

    private let readTypes: Set<HKSampleType> = [
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.stepCount),
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning)
    ]

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
                toShare: [],
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

    /// Throws `HealthKitError.notAuthorized` if the user has explicitly denied access.
    /// Note: HealthKit returns `.notDetermined` for read-only types even after granting,
    /// so only `.sharingDenied` is treated as denied.
    func ensureNotDenied(for type: HKObjectType) throws {
        let status = store.authorizationStatus(for: type)
        if status == .sharingDenied {
            logger.warning("HealthKit access denied for type: \(type.identifier)")
            throw HealthKitError.notAuthorized
        }
    }

    func execute<T>(_ query: T) async throws -> [T.Sample] where T: HKSampleQueryDescriptor {
        do {
            return try await query.result(for: store)
        } catch {
            logger.error("HK sample query failed: \(error.localizedDescription)")
            throw HealthKitError.queryFailed(error.localizedDescription)
        }
    }

    func executeStatistics(_ query: HKStatisticsQueryDescriptor) async throws -> HKStatistics? {
        do {
            return try await query.result(for: store)
        } catch {
            logger.error("HK statistics query failed: \(error.localizedDescription)")
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
