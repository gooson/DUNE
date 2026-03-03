import Foundation

/// Tracks when the last notification was sent per insight type to prevent notification fatigue.
/// Health data types: max once per calendar day.
/// Workout PR: no throttle (every PR triggers a notification).
final class NotificationThrottleStore: @unchecked Sendable {
    static let shared = NotificationThrottleStore()

    private let defaults: UserDefaults
    private let keyPrefix: String
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.keyPrefix = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".notificationThrottle."
        self.calendar = calendar
    }

    /// Returns true if a notification of this type can be sent now.
    func canSend(for type: HealthInsight.InsightType) -> Bool {
        // Workout PRs are never throttled
        if type == .workoutPR { return true }

        let key = keyPrefix + type.rawValue
        guard let lastDate = defaults.object(forKey: key) as? Date else {
            return true  // Never sent before
        }

        // Health data: throttle to once per calendar day
        return !calendar.isDate(lastDate, inSameDayAs: Date())
    }

    /// Records that a notification of this type was sent now.
    func recordSent(for type: HealthInsight.InsightType) {
        let key = keyPrefix + type.rawValue
        defaults.set(Date(), forKey: key)
    }

    /// Resets throttle for a specific type (for testing).
    func reset(for type: HealthInsight.InsightType) {
        let key = keyPrefix + type.rawValue
        defaults.removeObject(forKey: key)
    }
}
