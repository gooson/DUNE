import HealthKit

protocol HealthKitObserverStoring: Sendable {
    func execute(_ query: HKQuery)
    func stop(_ query: HKQuery)
    func enableBackgroundDelivery(
        for type: HKObjectType,
        frequency: HKUpdateFrequency,
        withCompletion completion: @escaping @Sendable (Bool, Error?) -> Void
    )
}

extension HKHealthStore: HealthKitObserverStoring {}

/// Manages HKObserverQuery registrations and HealthKit background delivery.
///
/// Observes 8 HealthKit data types. On change, requests a coordinated refresh
/// through `AppRefreshCoordinator` (which handles throttling) and evaluates
/// new samples for background notification delivery.
@MainActor
final class HealthKitObserverManager {
    private let store: any HealthKitObserverStoring
    private let coordinator: AppRefreshCoordinating
    private let notificationEvaluator: BackgroundNotificationEvaluator?

    /// Registration, retention, and stopping are synchronous on the same actor.
    private var queries: [HKObserverQuery] = []

    /// Sample types to observe with their background delivery frequency.
    private static let observedTypes: [(type: HKSampleType, frequency: HKUpdateFrequency)] = [
        // Core vitals — immediate delivery (affect Condition Score)
        (HKQuantityType(.heartRateVariabilitySDNN), .immediate),
        (HKQuantityType(.restingHeartRate), .immediate),
        (HKCategoryType(.sleepAnalysis), .immediate),
        // Infrequent body composition measurements should not wait for an hourly batch.
        (HKQuantityType(.bodyMass), .immediate),
        (HKQuantityType(.bodyFatPercentage), .immediate),
        (HKQuantityType(.bodyMassIndex), .immediate),
        // Secondary metrics — hourly delivery
        (HKQuantityType(.stepCount), .hourly),
        (HKSampleType.workoutType(), .hourly),
    ]

    init(
        store: any HealthKitObserverStoring,
        coordinator: AppRefreshCoordinating,
        notificationEvaluator: BackgroundNotificationEvaluator? = nil
    ) {
        self.store = store
        self.coordinator = coordinator
        self.notificationEvaluator = notificationEvaluator
    }

    /// Registers observer queries for all tracked types and enables background delivery.
    /// Restore at launch after a previous authorization request, or after the first request completes.
    /// HealthKit controls access to types without read permission.
    func startObserving() {
        let needsQueries = queries.isEmpty
        for entry in Self.observedTypes {
            if needsQueries {
                registerObserver(for: entry.type)
            }
            // Retry after foreground authorization in case launch-time delivery setup failed.
            enableBackgroundDelivery(for: entry.type, frequency: entry.frequency)
        }
    }

    /// Stops all observer queries. Call on dealloc or explicit cleanup.
    func stopObserving() {
        for query in queries {
            store.stop(query)
        }
        queries.removeAll()
        AppLogger.healthKit.info("[ObserverManager] Stopped all observer queries")
    }

    // MARK: - Private

    private func registerObserver(for sampleType: HKSampleType) {
        let typeName = sampleType.identifier

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [coordinator, notificationEvaluator] _, completionHandler, error in
            if let error {
                AppLogger.healthKit.error("[ObserverManager] Observer error for \(typeName): \(error.localizedDescription)")
                completionHandler()
                return
            }

            // Correction #92: error identification log
            AppLogger.healthKit.info("[ObserverManager] Change detected: \(typeName)")

            Self.processUpdate(completion: completionHandler) {
                async let refreshTask: Void = {
                    _ = await coordinator.requestRefresh(source: .healthKitObserver)
                }()
                async let notifyTask: Void = {
                    await notificationEvaluator?.evaluateAndNotify(sampleType: sampleType)
                }()
                async let bedtimeTask: Void = {
                    if sampleType.identifier == HKCategoryType(.sleepAnalysis).identifier {
                        await BedtimeReminderScheduler.shared.refreshSchedule(force: true)
                        await AppleWatchBedtimeReminderScheduler.shared.refreshSchedule(force: true)
                    }
                }()
                _ = await (refreshTask, notifyTask, bedtimeTask)
            }
        }

        queries.append(query)
        store.execute(query)

        AppLogger.healthKit.info("[ObserverManager] Registered observer for \(typeName)")
    }

    /// Keep HealthKit's background delivery alive until all asynchronous work finishes.
    @discardableResult
    nonisolated static func processUpdate(
        completion: @escaping () -> Void,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        let completion = ObserverCompletion(completion)
        return Task {
            defer { completion.finish() }
            await operation()
        }
    }

    private func enableBackgroundDelivery(for sampleType: HKSampleType, frequency: HKUpdateFrequency) {
        let typeName = sampleType.identifier

        store.enableBackgroundDelivery(for: sampleType, frequency: frequency) { success, error in
            if let error {
                AppLogger.healthKit.error("[ObserverManager] Background delivery failed for \(typeName): \(error.localizedDescription)")
            } else if success {
                AppLogger.healthKit.info("[ObserverManager] Background delivery enabled for \(typeName) (\(frequency.logDescription))")
            }
        }
    }
}

// MARK: - HKUpdateFrequency Debug

extension HKUpdateFrequency {
    var logDescription: String {
        switch self {
        case .immediate: return "immediate"
        case .hourly: return "hourly"
        case .daily: return "daily"
        case .weekly: return "weekly"
        @unknown default: return "unknown"
        }
    }
}

/// HealthKit supplies a non-Sendable callback. Transfer its single invocation to the task;
/// the lock ensures the callback can only be consumed once across threads.
private final class ObserverCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (() -> Void)?

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func finish() {
        let callback = lock.withLock {
            let callback = handler
            handler = nil
            return callback
        }
        callback?()
    }
}
