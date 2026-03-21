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
    nonisolated static let shared = WatchPostureMonitor()
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
    }

    // MARK: - Observable State

    private(set) var currentActivity: PostureActivityState = .unknown
    private(set) var sedentaryMinutesToday: Int = 0
    private(set) var standingMinutesToday: Int = 0
    private(set) var walkingMinutesToday: Int = 0
    private(set) var latestGaitScore: GaitQualityScore?
    private(set) var gaitScoresToday: [GaitQualityScore] = []
    private(set) var stretchReminderCount: Int = 0
    private(set) var isMonitoring = false

    /// Average gait score for today (nil if no walking sessions).
    var averageGaitScore: Int? {
        guard !gaitScoresToday.isEmpty else { return nil }
        let sum = gaitScoresToday.map(\.overall).reduce(0, +)
        return sum / gaitScoresToday.count
    }

    // MARK: - Private State

    private let activityManager = CMMotionActivityManager()
    private let motionManager = CMMotionManager()
    private let userDefaults: UserDefaults

    /// Timestamp when current stationary period started.
    private var sedentaryStartDate: Date?
    /// Accumulated sedentary seconds within current period (before threshold trigger).
    private var currentSedentarySeconds: TimeInterval = 0
    /// Timer that checks sedentary duration every minute.
    private var sedentaryCheckTask: Task<Void, Never>?
    /// Cooldown: last time DeviceMotion was collected.
    private var lastDeviceMotionCollectionDate: Date?
    /// Whether DeviceMotion is currently collecting.
    private var isCollectingDeviceMotion = false
    /// Buffer for DeviceMotion samples.
    private var deviceMotionSamples: [CMDeviceMotion] = []
    /// Task for stopping DeviceMotion after duration.
    private var deviceMotionStopTask: Task<Void, Never>?
    /// Date when today's summary was last reset.
    private var summaryResetDate: Date?

    var sedentaryThresholdMinutes: Int {
        let stored = userDefaults.integer(forKey: SettingsKey.sedentaryThresholdMinutes)
        return stored > 0 ? stored : Constants.defaultSedentaryThresholdMinutes
    }

    var isEnabled: Bool {
        userDefaults.bool(forKey: SettingsKey.isEnabled)
    }

    // MARK: - Init

    nonisolated init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
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
        guard CMMotionActivityManager.isActivityAvailable() else {
            Self.logger.warning("[PostureMonitor] Activity tracking not available")
            return
        }

        isMonitoring = true
        resetDailySummaryIfNeeded()
        startActivityTracking()
        startSedentaryCheckTimer()

        Self.logger.info("[PostureMonitor] Monitoring started")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        activityManager.stopActivityUpdates()
        stopDeviceMotionCollection()
        sedentaryCheckTask?.cancel()
        sedentaryCheckTask = nil
        sedentaryStartDate = nil

        Self.logger.info("[PostureMonitor] Monitoring stopped")
    }

    func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: SettingsKey.isEnabled)
        if enabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func setSedentaryThreshold(minutes: Int) {
        let clamped = max(15, min(120, minutes))
        userDefaults.set(clamped, forKey: SettingsKey.sedentaryThresholdMinutes)
    }

    // MARK: - Daily Summary

    func buildDailySummary() -> DailyPostureSummary {
        DailyPostureSummary(
            sedentaryMinutes: sedentaryMinutesToday,
            standingMinutes: standingMinutesToday,
            walkingMinutes: walkingMinutesToday,
            averageGaitScore: averageGaitScore,
            stretchRemindersTriggered: stretchReminderCount,
            date: summaryResetDate ?? Date()
        )
    }

    // MARK: - Activity Tracking

    private func startActivityTracking() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        activityManager.startActivityUpdates(to: queue) { [weak self] activity in
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
        currentActivity = newState

        // Accumulate time for previous state
        accumulateTimeForPreviousState(previousState)

        switch newState {
        case .stationary:
            if previousState != .stationary {
                sedentaryStartDate = Date()
                currentSedentarySeconds = 0
            }

        case .walking:
            sedentaryStartDate = nil
            currentSedentarySeconds = 0
            triggerGaitAnalysisIfReady()

        case .running, .unknown:
            sedentaryStartDate = nil
            currentSedentarySeconds = 0
        }
    }

    private func accumulateTimeForPreviousState(_ state: PostureActivityState) {
        // Approximate: add 1 minute per state change (activity updates typically every ~30-60s)
        switch state {
        case .stationary:
            sedentaryMinutesToday += 1
        case .walking:
            walkingMinutesToday += 1
        case .running:
            walkingMinutesToday += 1
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
                await self?.checkSedentaryDuration()
            }
        }
    }

    private func checkSedentaryDuration() {
        guard let startDate = sedentaryStartDate else { return }

        let elapsed = Date().timeIntervalSince(startDate)
        let thresholdSeconds = TimeInterval(sedentaryThresholdMinutes * 60)

        if elapsed >= thresholdSeconds {
            triggerStretchReminder()
            // Reset for next period
            sedentaryStartDate = Date()
            currentSedentarySeconds = 0
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
        if WorkoutManager.shared.isActive {
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
        deviceMotionSamples.removeAll()
        deviceMotionSamples.reserveCapacity(
            Int(Constants.deviceMotionSampleDurationSeconds * Constants.deviceMotionFrequencyHz)
        )

        motionManager.deviceMotionUpdateInterval = 1.0 / Constants.deviceMotionFrequencyHz

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self else { return }
            if let error {
                Self.logger.warning("[PostureMonitor] DeviceMotion error: \(error.localizedDescription)")
                return
            }
            guard let motion else { return }

            Task { @MainActor [weak self] in
                self?.deviceMotionSamples.append(motion)
            }
        }

        // Stop after duration
        deviceMotionStopTask?.cancel()
        deviceMotionStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.deviceMotionSampleDurationSeconds))
            guard !Task.isCancelled else { return }
            await self?.stopDeviceMotionCollection()
            await self?.processGaitSamples()
        }

        Self.logger.info("[PostureMonitor] Started DeviceMotion collection (\(Constants.deviceMotionSampleDurationSeconds)s)")
    }

    private func stopDeviceMotionCollection() {
        motionManager.stopDeviceMotionUpdates()
        isCollectingDeviceMotion = false
        deviceMotionStopTask?.cancel()
        deviceMotionStopTask = nil
        lastDeviceMotionCollectionDate = Date()
    }

    private func processGaitSamples() {
        let samples = deviceMotionSamples
        deviceMotionSamples.removeAll()

        guard let score = GaitAnalyzer.analyze(samples) else {
            Self.logger.info("[PostureMonitor] Insufficient samples for gait analysis (\(samples.count))")
            return
        }

        latestGaitScore = score
        gaitScoresToday.append(score)
        Self.logger.info("[PostureMonitor] Gait score: \(score.overall) (symmetry: \(score.symmetry), regularity: \(score.regularity))")
    }

    // MARK: - Daily Reset

    private func resetDailySummaryIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let resetDate = summaryResetDate, calendar.isDate(resetDate, inSameDayAs: today) {
            return // Already reset today
        }

        sedentaryMinutesToday = 0
        standingMinutesToday = 0
        walkingMinutesToday = 0
        gaitScoresToday.removeAll()
        stretchReminderCount = 0
        latestGaitScore = nil
        summaryResetDate = today
    }
}
