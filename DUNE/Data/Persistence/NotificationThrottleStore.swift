import Foundation

/// Tracks when the last notification was sent per insight type to prevent notification fatigue.
/// Health data types: max once per calendar day.
/// Workout PR: no throttle (every PR triggers a notification).
final class NotificationThrottleStore: @unchecked Sendable {
    static let shared = NotificationThrottleStore()

    private let defaults: UserDefaults
    private let keyPrefix: String
    private let calendar: Calendar
    private let dailyBudgetLimit: Int
    private let dedupWindowSeconds: TimeInterval
    private let queue = DispatchQueue(label: "com.dune.notification-throttle-store")

    private enum Keys {
        static let dailyCountDateSuffix = "dailyCountDate"
        static let dailyCountSuffix = "dailyCount"
        static let dedupPrefix = "dedup."
    }

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        dailyBudgetLimit: Int = 6,
        dedupWindowSeconds: TimeInterval = 60 * 60
    ) {
        self.defaults = defaults
        self.keyPrefix = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".notificationThrottle."
        self.calendar = calendar
        self.dailyBudgetLimit = max(dailyBudgetLimit, 1)
        self.dedupWindowSeconds = max(dedupWindowSeconds, 0)
    }

    /// Returns true if a notification of this type can be sent now.
    func canSend(for type: HealthInsight.InsightType, now: Date = Date()) -> Bool {
        queue.sync {
            canSendTypeLocked(for: type, now: now)
        }
    }

    /// Returns true if this specific insight should be delivered now.
    /// Applies type throttle + dedup window + daily budget.
    func canSend(insight: HealthInsight, now: Date = Date()) -> Bool {
        queue.sync {
            canSendInsightLocked(insight: insight, now: now)
        }
    }

    /// Atomically checks policy and records the send when allowed.
    /// Use this from background delivery paths to avoid race-condition duplicates.
    func shouldSendAndRecord(insight: HealthInsight, now: Date = Date()) -> Bool {
        queue.sync {
            guard canSendInsightLocked(insight: insight, now: now) else { return false }
            recordSentInsightLocked(insight: insight, now: now)
            return true
        }
    }

    /// Records that a notification of this type was sent now.
    func recordSent(for type: HealthInsight.InsightType) {
        let now = Date()
        queue.sync {
            recordSentTypeLocked(for: type, now: now)
        }
    }

    /// Records this specific insight as delivered.
    func recordSent(insight: HealthInsight, now: Date = Date()) {
        queue.sync {
            recordSentInsightLocked(insight: insight, now: now)
        }
    }

    /// Resets throttle for a specific type (for testing).
    func reset(for type: HealthInsight.InsightType) {
        queue.sync {
            let key = keyPrefix + type.rawValue
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Type Throttle

    private func canSendTypeLocked(for type: HealthInsight.InsightType, now: Date) -> Bool {
        // Workout PRs are never throttled at type level.
        if type == .workoutPR { return true }

        let key = keyPrefix + type.rawValue
        guard let lastDate = defaults.object(forKey: key) as? Date else {
            return true  // Never sent before
        }

        // Health data: throttle to once per calendar day.
        return !calendar.isDate(lastDate, inSameDayAs: now)
    }

    private func recordSentTypeLocked(for type: HealthInsight.InsightType, now: Date) {
        let key = keyPrefix + type.rawValue
        defaults.set(now, forKey: key)
    }

    private func canSendInsightLocked(insight: HealthInsight, now: Date) -> Bool {
        guard canSendTypeLocked(for: insight.type, now: now) else { return false }
        guard !isRecentDuplicateLocked(of: insight, now: now) else { return false }
        guard hasRemainingDailyBudgetLocked(for: insight, now: now) else { return false }
        return true
    }

    private func recordSentInsightLocked(insight: HealthInsight, now: Date) {
        recordSentTypeLocked(for: insight.type, now: now)
        recordDedupSentLocked(insight: insight, now: now)
        incrementDailyCountIfNeededLocked(for: insight, now: now)
    }

    // MARK: - Dedup

    private func isRecentDuplicateLocked(of insight: HealthInsight, now: Date) -> Bool {
        guard dedupWindowSeconds > 0 else { return false }
        let key = dedupKey(for: insight)
        guard let lastDate = defaults.object(forKey: key) as? Date else { return false }
        return now.timeIntervalSince(lastDate) < dedupWindowSeconds
    }

    private func recordDedupSentLocked(insight: HealthInsight, now: Date) {
        let key = dedupKey(for: insight)
        defaults.set(now, forKey: key)
    }

    private func dedupKey(for insight: HealthInsight) -> String {
        let routeKey: String
        if let route = insight.route {
            switch route.destination {
            case .workoutDetail:
                routeKey = "workout:\(route.workoutID ?? "-")"
            }
        } else {
            routeKey = "none"
        }
        let signature = [
            insight.type.rawValue,
            routeKey,
            insight.title,
            insight.body
        ].joined(separator: "|")
        return keyPrefix + Keys.dedupPrefix + signature
    }

    // MARK: - Daily Budget

    private func hasRemainingDailyBudgetLocked(for insight: HealthInsight, now: Date) -> Bool {
        // Always deliver high-signal alerts even when budget is exhausted.
        switch insight.severity {
        case .attention, .celebration:
            return true
        case .informational:
            break
        }

        let count = dailyCountLocked(now: now)
        return count < dailyBudgetLimit
    }

    private func incrementDailyCountIfNeededLocked(for insight: HealthInsight, now: Date) {
        // High-signal alerts are not counted against the informational budget.
        guard insight.severity == .informational else { return }
        let key = keyPrefix + Keys.dailyCountSuffix
        defaults.set(dailyCountLocked(now: now) + 1, forKey: key)
        defaults.set(now, forKey: keyPrefix + Keys.dailyCountDateSuffix)
    }

    private func dailyCountLocked(now: Date) -> Int {
        let dateKey = keyPrefix + Keys.dailyCountDateSuffix
        let countKey = keyPrefix + Keys.dailyCountSuffix
        guard let savedDate = defaults.object(forKey: dateKey) as? Date else {
            return 0
        }
        guard calendar.isDate(savedDate, inSameDayAs: now) else {
            return 0
        }
        return defaults.integer(forKey: countKey)
    }
}
