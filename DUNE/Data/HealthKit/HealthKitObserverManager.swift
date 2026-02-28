import HealthKit

/// Manages HKObserverQuery registrations and HealthKit background delivery.
///
/// Observes 8 HealthKit data types. On change, requests a coordinated refresh
/// through `AppRefreshCoordinator` (which handles throttling).
final class HealthKitObserverManager: Sendable {
    private let store: HKHealthStore
    private let coordinator: AppRefreshCoordinating

    /// Observer queries are stored here so they remain alive.
    /// Access is serialized through the internal actor.
    private let state = StateActor()

    /// Sample types to observe with their background delivery frequency.
    private static let observedTypes: [(type: HKSampleType, frequency: HKUpdateFrequency)] = [
        // Core vitals — immediate delivery (affect Condition Score)
        (HKQuantityType(.heartRateVariabilitySDNN), .immediate),
        (HKQuantityType(.restingHeartRate), .immediate),
        (HKCategoryType(.sleepAnalysis), .immediate),
        // Secondary metrics — hourly delivery
        (HKQuantityType(.stepCount), .hourly),
        (HKQuantityType(.bodyMass), .hourly),
        (HKQuantityType(.bodyFatPercentage), .hourly),
        (HKQuantityType(.bodyMassIndex), .hourly),
        (HKObjectType.workoutType() as! HKSampleType, .hourly),
    ]

    init(
        store: HKHealthStore,
        coordinator: AppRefreshCoordinating
    ) {
        self.store = store
        self.coordinator = coordinator
    }

    /// Registers observer queries for all tracked types and enables background delivery.
    /// Call once at app launch (after HealthKit authorization).
    /// Types without read permission are silently skipped.
    func startObserving() {
        for entry in Self.observedTypes {
            registerObserver(for: entry.type)
            enableBackgroundDelivery(for: entry.type, frequency: entry.frequency)
        }
    }

    /// Stops all observer queries. Call on dealloc or explicit cleanup.
    func stopObserving() async {
        let queries = await state.removeAllQueries()
        for query in queries {
            store.stop(query)
        }
        AppLogger.healthKit.info("[ObserverManager] Stopped all observer queries")
    }

    // MARK: - Private

    private func registerObserver(for sampleType: HKSampleType) {
        let typeName = sampleType.identifier

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [coordinator] _, completionHandler, error in
            // completionHandler MUST be called to receive future notifications
            defer { completionHandler() }

            if let error {
                AppLogger.healthKit.error("[ObserverManager] Observer error for \(typeName): \(error.localizedDescription)")
                return
            }

            // Correction #92: error identification log
            AppLogger.healthKit.info("[ObserverManager] Change detected: \(typeName)")

            Task {
                _ = await coordinator.requestRefresh(source: .healthKitObserver)
            }
        }

        store.execute(query)

        Task {
            await state.addQuery(query, for: typeName)
        }

        AppLogger.healthKit.info("[ObserverManager] Registered observer for \(typeName)")
    }

    private func enableBackgroundDelivery(for sampleType: HKSampleType, frequency: HKUpdateFrequency) {
        let typeName = sampleType.identifier

        store.enableBackgroundDelivery(for: sampleType, frequency: frequency) { success, error in
            if let error {
                AppLogger.healthKit.error("[ObserverManager] Background delivery failed for \(typeName): \(error.localizedDescription)")
            } else if success {
                AppLogger.healthKit.info("[ObserverManager] Background delivery enabled for \(typeName) (\(frequency.debugDescription))")
            }
        }
    }
}

// MARK: - State Actor

extension HealthKitObserverManager {
    /// Thread-safe storage for active observer queries.
    private actor StateActor {
        private var queries: [String: HKObserverQuery] = [:]

        func addQuery(_ query: HKObserverQuery, for key: String) {
            queries[key] = query
        }

        func removeAllQueries() -> [HKObserverQuery] {
            let all = Array(queries.values)
            queries.removeAll()
            return all
        }
    }
}

// MARK: - HKUpdateFrequency Debug

extension HKUpdateFrequency {
    var debugDescription: String {
        switch self {
        case .immediate: return "immediate"
        case .hourly: return "hourly"
        case .daily: return "daily"
        case .weekly: return "weekly"
        @unknown default: return "unknown"
        }
    }
}
