import CoreMotion
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

    private let activityManager = CMMotionActivityManager()
    private let motionManager = CMMotionManager()
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
        activityManager.startActivityUpdates(to: activityQueue) { [weak self] activity in
            guard let self, let activity else { return }
            let state = Self.mapActivity(activity)

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleActivityChange(state)
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
            break // Sedentary check timer handles threshold alerts

        case .walking:
            triggerGaitAnalysisIfReady()

        case .running, .unknown:
            break
        }
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
                guard !Task.isCancelled else { break }
                await self?.periodicCheck()
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

        if elapsedMinutes >= sedentaryThresholdMinutes {
            triggerStretchReminder()
            // Reset start for next period
            activityStateStartDate = Date()
        }
    }

    // MARK: - Stretch Reminder

    private func triggerStretchReminder() {
        // Suppress during night hours
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= Constants.nightStartHour || hour < Constants.nightEndHour {
            Self.logger.info("[PostureMonitor] Suppressing night-time stretch reminder")
            return
        }

        // Suppress during active workout
        if isWorkoutActive() {
            Self.logger.info("[PostureMonitor] Suppressing stretch reminder during workout")
            return
        }

        stretchReminderCount += 1
        scheduleLocalNotification()
    }

    private func scheduleLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to stretch!")
        content.body = String(localized: "You've been sitting for a while. Take a moment to stand and stretch.")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(Constants.notificationIdentifier)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.logger.error("[PostureMonitor] Notification failed: \(error.localizedDescription)")
            }
        }
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

        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self else { return }
            if let error {
                Self.logger.warning("[PostureMonitor] DeviceMotion error: \(error.localizedDescription)")
                return
            }
            guard let motion else { return }

            Task { @MainActor [weak self] in
                guard let self, self.deviceMotionGeneration == currentGeneration else { return }
                self.deviceMotionSamples.append(motion)
            }
        }

        // Stop after duration
        deviceMotionStopTask?.cancel()
        deviceMotionStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.deviceMotionSampleDurationSeconds))
            guard !Task.isCancelled else { return }
            await self?.finishDeviceMotionCollection()
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
