import Foundation

/// Manages per-type notification enable/disable settings in UserDefaults.
/// Key prefix uses bundle identifier for test/production isolation (correction #76).
final class NotificationSettingsStore: @unchecked Sendable {
    static let shared = NotificationSettingsStore()

    private let defaults: UserDefaults
    private let keyPrefix: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.keyPrefix = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".notificationSettings."
    }

    /// Returns whether notifications are enabled for the given insight type.
    /// Defaults to true (all types enabled by default).
    func isEnabled(for type: HealthInsight.InsightType) -> Bool {
        let key = keyPrefix + type.rawValue
        // If key doesn't exist, object(forKey:) returns nil → default to true
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    /// Sets whether notifications are enabled for the given insight type.
    func setEnabled(_ enabled: Bool, for type: HealthInsight.InsightType) {
        let key = keyPrefix + type.rawValue
        defaults.set(enabled, forKey: key)
    }

    /// Master toggle: enables or disables all notification types at once.
    func setAllEnabled(_ enabled: Bool) {
        for type in HealthInsight.InsightType.allCases {
            setEnabled(enabled, for: type)
        }
    }

    /// Returns true if at least one type is enabled.
    var hasAnyEnabled: Bool {
        HealthInsight.InsightType.allCases.contains { isEnabled(for: $0) }
    }
}
