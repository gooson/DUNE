@preconcurrency import CoreMotion
import Foundation
import Observation
import OSLog
import UserNotifications
import WatchKit

/// Monitors daily posture patterns using CMMotionActivityManager (sedentary detection)
/// and CMDeviceMotion (gait quality during walking).
///
/// - Sedentary detection: Tracks time in stationary state, triggers stretch reminders.
/// - Gait analysis: Collects 10-second device motion samples during walking, computes quality score.
/// - Battery-aware: DeviceMotion has a 5-minute cooldown between collections.
@Observable
@MainActor
final class WatchPostureMonitor {
    static let shared = WatchPostureMonitor()
    nonisolated private static let logger = Logger(subsystem: "com.raftel.dailve", category: "PostureMonitor")

    // MARK: - Settings Keys

    enum SettingsKey {
        static let isEnabled = "isPostureMonitoringEnabled"
        static let sedentaryThresholdMinutes = "postureSedentaryThresholdMinutes"
    }

    // MARK: - Constants

    private enum Constants {
        static let defaultSedentaryThresholdMinutes = 45
        static let deviceMotionSampleDurationSeconds: TimeInterval = 10
        static let deviceMotionCooldownSeconds: TimeInterval = 300 // 5 minutes
        static let deviceMotionFrequencyHz: Double = 50
        static let notificationIdentifier = "com.raftel.dune.watch.stretch-reminder"
        /// Identifier prefix for scheduled (future) stretch notifications.
        static let scheduledNotificationPrefix = "com.raftel.dune.watch.stretch-scheduled"
        /// Maximum pending stretch notifications to schedule ahead.
        static let maxPendingNotifications = 3
        /// Suppress notifications during night hours (22:00-06:00).
        static let nightStartHour = 22
        static let nightEndHour = 6
        /// Stop DeviceMotion collection when battery is below this level.
        static let lowBatteryThreshold: Float = 0.20
        /// Maximum daily minutes for any single counter (24h = 1440 min).
        static let maxDailyMinutes = 1440
    }

    // MARK: - Observable State

    private(set) var currentActivity: PostureActivityState = .unknown
    private(set) var sedentaryMinutesToday: Int = 0
    private(set) var walkingMinutesToday: Int = 0
    private(set) var latestGaitScore: GaitQualityScore?
    private(set) var gaitScoresToday: [GaitQualityScore] = []
    private(set) var stretchReminderCount: Int = 0
    private(set) var isMonitoring = false

    /// Stored property: cached UserDefaults value (performance-patterns.md).
    private(set) var sedentaryThresholdMinutes: Int
    /// Stored property: cached UserDefaults value (performance-patterns.md).
    private(set) var isEnabled: Bool

    /// Average gait score for today (nil if no walking sessions).
    /// Cached: updated only when gaitScoresToday changes.
    private(set) var cachedAverageGaitScore: Int?

    // MARK: - Private State

    private nonisolated(unsafe) let activityManager = CMMotionActivityManager()
    private nonisolated(unsafe) let motionManager = CMMotionManager()
    private nonisolated(unsafe) let userDefaults: UserDefaults
    /// Injected closure to check workout active state (testability).
    private let isWorkoutActive: @MainActor () -> Bool

    /// Reusable operation queues (avoid per-cycle allocation).
    private let activityQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "com.raftel.dune.posture.activity"
        return q
    }()
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "com.raftel.dune.posture.motion"
        return q
    }()

    /// Timestamp when current activity state started (for elapsed-time-based accumulation).
    private var activityStateStartDate: Date?
    /// Timer that checks sedentary duration every minute.
    private var sedentaryCheckTask: Task<Void, Never>?
    /// Cooldown: last time DeviceMotion was collected.
    private var lastDeviceMotionCollectionDate: Date?
    /// Whether DeviceMotion is currently collecting.
    private var isCollectingDeviceMotion = false
    /// Generation counter to discard stale in-flight DeviceMotion appends.
    private var deviceMotionGeneration: Int = 0
    /// Buffer for DeviceMotion samples.
    private var deviceMotionSamples: [CMDeviceMotion] = []
    /// Task for stopping DeviceMotion after duration.
    private var deviceMotionStopTask: Task<Void, Never>?
    /// Date when today's summary was last reset.
    private var summaryResetDate: Date?
    /// Throttle: last time posture summary was sent to iPhone.
    private var lastSummarySyncDate: Date?

    // MARK: - Init

    init(
        userDefaults: UserDefaults = .standard,
        isWorkoutActive: @MainActor @escaping () -> Bool = { WorkoutManager.shared.isActive }
    ) {
        self.userDefaults = userDefaults
        self.isWorkoutActive = isWorkoutActive

        let stored = userDefaults.integer(forKey: SettingsKey.sedentaryThresholdMinutes)
        self.sedentaryThresholdMinutes = stored > 0 ? stored : Constants.defaultSedentaryThresholdMinutes
        self.isEnabled = userDefaults.bool(forKey: SettingsKey.isEnabled)
    }

    // MARK: - Lifecycle

    func startMonitoringIfEnabled() {
        guard isEnabled else {
            stopMonitoring()
            return
        }
        startMonitoring()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        requestNotificationAuthorization()

#if targetEnvironment(simulator)
        Self.logger.info("[PostureMonitor] CoreMotion not available on simulator — skipping")
        isMonitoring = true
        resetDailySummaryIfNeeded()
        startSedentaryCheckTimer()
        return
#else
        guard CMMotionActivityManager.isActivityAvailable() else {
            Self.logger.warning("[PostureMonitor] Activity tracking not available")
            return
        }

        let authStatus = CMMotionActivityManager.authorizationStatus()
        guard authStatus != .denied, authStatus != .restricted else {
            Self.logger.warning("[PostureMonitor] Motion authorization denied/restricted")
            return
        }

        isMonitoring = true
        resetDailySummaryIfNeeded()
        startActivityTracking()
        startSedentaryCheckTimer()

        Self.logger.info("[PostureMonitor] Monitoring started")
#endif
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        activityManager.stopActivityUpdates()
        stopDeviceMotionCollection()
        sedentaryCheckTask?.cancel()
        sedentaryCheckTask = nil
        activityStateStartDate = nil
        cancelScheduledStretchNotifications()

        Self.logger.info("[PostureMonitor] Monitoring stopped")
    }

    func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: SettingsKey.isEnabled)
        isEnabled = enabled
        if enabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func setSedentaryThreshold(minutes: Int) {
        let clamped = max(15, min(120, minutes))
        userDefaults.set(clamped, forKey: SettingsKey.sedentaryThresholdMinutes)
        sedentaryThresholdMinutes = clamped

        // Reschedule if currently stationary
        if currentActivity == .stationary, isMonitoring {
            scheduleStretchNotifications()
        }
    }

    // MARK: - Daily Summary

    func buildDailySummary() -> DailyPostureSummary {
        DailyPostureSummary(
            sedentaryMinutes: sedentaryMinutesToday,
            walkingMinutes: walkingMinutesToday,
            averageGaitScore: cachedAverageGaitScore,
            stretchRemindersTriggered: stretchReminderCount,
            date: summaryResetDate ?? Date()
        )
    }

    // MARK: - Activity Tracking

    private func startActivityTracking() {
        Self.registerActivityCallback(manager: activityManager, queue: activityQueue)
    }

    /// Register CoreMotion activity callback. Must be nonisolated so the closure
    /// does NOT inherit @MainActor isolation (Swift 6 _dispatch_assert_queue_fail).
    nonisolated private static func registerActivityCallback(
        manager: CMMotionActivityManager,
        queue: OperationQueue
    ) {
        manager.startActivityUpdates(to: queue) { activity in
            guard let activity else { return }
            let state = mapActivity(activity)

            Task { @MainActor in
                shared.handleActivityChange(state)
            }
        }
    }

    /// Register CoreMotion device motion callback. Must be nonisolated so the closure
    /// does NOT inherit @MainActor isolation (Swift 6 _dispatch_assert_queue_fail).
    nonisolated private static func registerDeviceMotionCallback(
        manager: CMMotionManager,
        queue: OperationQueue,
        generation: Int
    ) {
        manager.startDeviceMotionUpdates(to: queue) { motion, error in
            if let error {
                logger.warning("[PostureMonitor] DeviceMotion error: \(error.localizedDescription)")
                return
            }
            guard let motion else { return }

            Task { @MainActor in
                let monitor = shared
                guard monitor.deviceMotionGeneration == generation else { return }
                monitor.deviceMotionSamples.append(motion)
            }
        }
    }

    nonisolated private static func mapActivity(_ activity: CMMotionActivity) -> PostureActivityState {
        if activity.walking { return .walking }
        if activity.running { return .running }
        if activity.stationary { return .stationary }
        return .unknown
    }

    private func handleActivityChange(_ newState: PostureActivityState) {
        let previousState = currentActivity

        // Accumulate elapsed time for previous state
        accumulateTimeForPreviousState(previousState)

        currentActivity = newState
        activityStateStartDate = Date()

        switch newState {
        case .stationary:
            scheduleStretchNotifications()

        case .walking:
            cancelScheduledStretchNotifications()
            triggerGaitAnalysisIfReady()

        case .running, .unknown:
            cancelScheduledStretchNotifications()
        }

        // Sync updated summary to iPhone on state transition
        syncSummaryToPhone()
    }

    /// Sends current daily summary to iPhone via WatchConnectivity.
    /// Throttled to at most once per 60 seconds to avoid hot-path encoding.
    /// `force: true` bypasses throttle (e.g. after stretch reminder).
    private func syncSummaryToPhone(force: Bool = false) {
        let now = Date()
        if !force, let lastSync = lastSummarySyncDate,
           now.timeIntervalSince(lastSync) < 60 {
            return
        }
        lastSummarySyncDate = now
        WatchConnectivityManager.shared.sendPostureSummary(buildDailySummary())
    }

    /// Accumulate elapsed time since last state change into the appropriate daily counter.
    private func accumulateTimeForPreviousState(_ state: PostureActivityState) {
        guard let startDate = activityStateStartDate else { return }
        let elapsedMinutes = Int(Date().timeIntervalSince(startDate) / 60)
        guard elapsedMinutes > 0 else { return }

        switch state {
        case .stationary:
            sedentaryMinutesToday = min(Constants.maxDailyMinutes, sedentaryMinutesToday + elapsedMinutes)
        case .walking, .running:
            walkingMinutesToday = min(Constants.maxDailyMinutes, walkingMinutesToday + elapsedMinutes)
        case .unknown:
            break
        }
    }

    // MARK: - Sedentary Check Timer

    private func startSedentaryCheckTimer() {
        sedentaryCheckTask?.cancel()
        sedentaryCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, let self else { break }
                self.periodicCheck()
            }
        }
    }

    private func periodicCheck() {
        resetDailySummaryIfNeeded()
        checkSedentaryDuration()
    }

    private func checkSedentaryDuration() {
        guard currentActivity == .stationary,
              let startDate = activityStateStartDate else { return }

        let elapsedMinutes = Int(Date().timeIntervalSince(startDate) / 60)

        // Update counter and sync when threshold is crossed (foreground only).
        // Actual notification delivery is handled by OS via scheduleStretchNotifications().
        if elapsedMinutes >= sedentaryThresholdMinutes {
            let periods = elapsedMinutes / sedentaryThresholdMinutes
            let expectedCount = stretchReminderCount + periods
            if expectedCount > stretchReminderCount {
                stretchReminderCount = expectedCount
                syncSummaryToPhone(force: true)
            }
            // Advance start date to the last completed period boundary
            activityStateStartDate = startDate.addingTimeInterval(
                TimeInterval(periods * sedentaryThresholdMinutes * 60)
            )
        }
    }

    // MARK: - Notification Authorization

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Self.logger.error("[PostureMonitor] Notification auth error: \(error.localizedDescription)")
            }
            Self.logger.info("[PostureMonitor] Notification authorization granted: \(granted)")
        }
    }

    // MARK: - Scheduled Stretch Notifications

    /// Schedules future stretch-reminder notifications at 1x, 2x, 3x threshold intervals.
    /// Uses `UNTimeIntervalNotificationTrigger` so the OS delivers even when the app is suspended.
    /// Skips individual notifications whose delivery time falls in the night window (22:00–06:00).
    private func scheduleStretchNotifications() {
        // Suppress during active workout
        if isWorkoutActive() {
            Self.logger.info("[PostureMonitor] Suppressing scheduled stretch — workout active")
            return
        }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        let thresholdSeconds = TimeInterval(sedentaryThresholdMinutes * 60)

        // Cancel any previously scheduled stretch notifications before re-scheduling
        cancelScheduledStretchNotifications()

        var scheduledCount = 0
        for index in 0..<Constants.maxPendingNotifications {
            let delay = thresholdSeconds * Double(index + 1)
            let deliveryDate = now.addingTimeInterval(delay)
            let deliveryHour = calendar.component(.hour, from: deliveryDate)

            // Skip notifications that would deliver during night hours
            if deliveryHour >= Constants.nightStartHour || deliveryHour < Constants.nightEndHour {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "Time to stretch!")
            content.body = String(localized: "You've been sitting for a while. Take a moment to stand and stretch.")
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(Constants.scheduledNotificationPrefix)-\(index)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    Self.logger.error("[PostureMonitor] Failed to schedule notification \(index): \(error.localizedDescription)")
                }
            }
            scheduledCount += 1
        }

        Self.logger.info("[PostureMonitor] Scheduled \(scheduledCount) stretch notifications (interval: \(self.sedentaryThresholdMinutes)min)")
    }

    /// Identifiers for all scheduled stretch notification slots.
    private static let scheduledNotificationIdentifiers: [String] = {
        (0..<Constants.maxPendingNotifications).map {
            "\(Constants.scheduledNotificationPrefix)-\($0)"
        }
    }()

    /// Cancels all pending scheduled stretch notifications.
    private func cancelScheduledStretchNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: Self.scheduledNotificationIdentifiers
        )
    }

    // MARK: - Gait Analysis

    private func triggerGaitAnalysisIfReady() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !isCollectingDeviceMotion else { return }

        // Cooldown check
        if let lastCollection = lastDeviceMotionCollectionDate,
           Date().timeIntervalSince(lastCollection) < Constants.deviceMotionCooldownSeconds {
            return
        }

        // Battery check
#if !targetEnvironment(simulator)
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        let batteryLevel = WKInterfaceDevice.current().batteryLevel
        if batteryLevel >= 0, batteryLevel < Constants.lowBatteryThreshold {
            Self.logger.info("[PostureMonitor] Skipping gait analysis due to low battery (\(batteryLevel))")
            return
        }
#endif

        startDeviceMotionCollection()
    }

    private func startDeviceMotionCollection() {
        isCollectingDeviceMotion = true
        deviceMotionGeneration += 1
        let currentGeneration = deviceMotionGeneration
        deviceMotionSamples.removeAll()
        deviceMotionSamples.reserveCapacity(
            Int(Constants.deviceMotionSampleDurationSeconds * Constants.deviceMotionFrequencyHz)
        )

        motionManager.deviceMotionUpdateInterval = 1.0 / Constants.deviceMotionFrequencyHz

        Self.registerDeviceMotionCallback(
            manager: motionManager,
            queue: motionQueue,
            generation: currentGeneration
        )

        // Stop after duration
        deviceMotionStopTask?.cancel()
        deviceMotionStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.deviceMotionSampleDurationSeconds))
            guard !Task.isCancelled, let self else { return }
            self.finishDeviceMotionCollection()
        }

        Self.logger.info("[PostureMonitor] Started DeviceMotion collection (\(Constants.deviceMotionSampleDurationSeconds)s)")
    }

    private func finishDeviceMotionCollection() {
        motionManager.stopDeviceMotionUpdates()
        isCollectingDeviceMotion = false
        deviceMotionStopTask?.cancel()
        deviceMotionStopTask = nil
        lastDeviceMotionCollectionDate = Date()

        // Snapshot samples and clear buffer
        let samples = deviceMotionSamples
        deviceMotionSamples.removeAll()

        processGaitSamples(samples)
    }

    private func stopDeviceMotionCollection() {
        motionManager.stopDeviceMotionUpdates()
        isCollectingDeviceMotion = false
        deviceMotionGeneration += 1 // Invalidate any in-flight appends
        deviceMotionStopTask?.cancel()
        deviceMotionStopTask = nil
        lastDeviceMotionCollectionDate = Date()
    }

    private func processGaitSamples(_ samples: [CMDeviceMotion]) {
        guard let score = GaitAnalyzer.analyze(samples) else {
            Self.logger.info("[PostureMonitor] Insufficient samples for gait analysis (\(samples.count))")
            return
        }

        latestGaitScore = score
        gaitScoresToday.append(score)
        updateCachedAverageGaitScore()
        Self.logger.info("[PostureMonitor] Gait score: \(score.overall) (symmetry: \(score.symmetry), regularity: \(score.regularity))")
    }

    /// Update cached average gait score (avoids recomputation on every View access).
    private func updateCachedAverageGaitScore() {
        guard !gaitScoresToday.isEmpty else {
            cachedAverageGaitScore = nil
            return
        }
        let sum = gaitScoresToday.map(\.overall).reduce(0, +)
        cachedAverageGaitScore = Int((Double(sum) / Double(gaitScoresToday.count)).rounded())
    }

    // MARK: - Daily Reset

    private func resetDailySummaryIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let resetDate = summaryResetDate, calendar.isDate(resetDate, inSameDayAs: today) {
            return // Already reset today
        }

        sedentaryMinutesToday = 0
        walkingMinutesToday = 0
        gaitScoresToday.removeAll()
        stretchReminderCount = 0
        latestGaitScore = nil
        cachedAverageGaitScore = nil
        summaryResetDate = today
    }
}
