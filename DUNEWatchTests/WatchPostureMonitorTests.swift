import Foundation
import Testing
@testable import DUNEWatch

@Suite("WatchPostureMonitor Tests")
@MainActor
struct WatchPostureMonitorTests {

    // MARK: - Helpers

    private func makeSUT(
        isEnabled: Bool = true,
        thresholdMinutes: Int = 45,
        isWorkoutActive: @MainActor @escaping () -> Bool = { false }
    ) -> WatchPostureMonitor {
        let defaults = UserDefaults(suiteName: "WatchPostureMonitorTests-\(UUID().uuidString)")!
        defaults.set(isEnabled, forKey: WatchPostureMonitor.SettingsKey.isEnabled)
        if thresholdMinutes > 0 {
            defaults.set(thresholdMinutes, forKey: WatchPostureMonitor.SettingsKey.sedentaryThresholdMinutes)
        }
        return WatchPostureMonitor(
            userDefaults: defaults,
            isWorkoutActive: isWorkoutActive
        )
    }

    // MARK: - Initialization

    @Test("Default threshold is 45 minutes when not set in UserDefaults")
    func defaultThreshold() {
        let defaults = UserDefaults(suiteName: "PostureTest-\(UUID().uuidString)")!
        let monitor = WatchPostureMonitor(userDefaults: defaults, isWorkoutActive: { false })
        #expect(monitor.sedentaryThresholdMinutes == 45)
    }

    @Test("Reads threshold from UserDefaults when set")
    func storedThreshold() {
        let monitor = makeSUT(thresholdMinutes: 60)
        #expect(monitor.sedentaryThresholdMinutes == 60)
    }

    @Test("isEnabled reads from UserDefaults")
    func enabledFromDefaults() {
        let enabled = makeSUT(isEnabled: true)
        #expect(enabled.isEnabled == true)

        let disabled = makeSUT(isEnabled: false)
        #expect(disabled.isEnabled == false)
    }

    // MARK: - setEnabled

    @Test("setEnabled(true) updates isEnabled")
    func setEnabledTrue() {
        let monitor = makeSUT(isEnabled: false)
        monitor.setEnabled(true)
        #expect(monitor.isEnabled == true)
    }

    @Test("setEnabled(false) updates isEnabled and stops monitoring")
    func setEnabledFalse() {
        let monitor = makeSUT(isEnabled: true)
        monitor.setEnabled(false)
        #expect(monitor.isEnabled == false)
        #expect(monitor.isMonitoring == false)
    }

    // MARK: - setSedentaryThreshold

    @Test("setSedentaryThreshold clamps to 15-120 range")
    func thresholdClamping() {
        let monitor = makeSUT()
        monitor.setSedentaryThreshold(minutes: 10)
        #expect(monitor.sedentaryThresholdMinutes == 15)

        monitor.setSedentaryThreshold(minutes: 200)
        #expect(monitor.sedentaryThresholdMinutes == 120)

        monitor.setSedentaryThreshold(minutes: 60)
        #expect(monitor.sedentaryThresholdMinutes == 60)
    }

    // MARK: - Daily Summary

    @Test("buildDailySummary returns current counters")
    func buildSummary() {
        let monitor = makeSUT()
        let summary = monitor.buildDailySummary()
        #expect(summary.sedentaryMinutes == 0)
        #expect(summary.walkingMinutes == 0)
        #expect(summary.averageGaitScore == nil)
        #expect(summary.stretchRemindersTriggered == 0)
    }

    // MARK: - Initial State

    @Test("Initial activity state is unknown")
    func initialState() {
        let monitor = makeSUT()
        #expect(monitor.currentActivity == .unknown)
        #expect(monitor.stretchReminderCount == 0)
        #expect(monitor.sedentaryMinutesToday == 0)
    }
}
