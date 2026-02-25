import Foundation

/// Persists user-selected pinned metrics for Today tab.
/// Uses bundle identifier prefix for environment isolation.
final class TodayPinnedMetricsStore: @unchecked Sendable {
    static let shared = TodayPinnedMetricsStore()

    private let defaults: UserDefaults
    private let key: String

    static let maxPinnedCount = 3
    static let fallback: [HealthMetric.Category] = [.hrv, .rhr, .sleep]
    static let allowedCategories: Set<HealthMetric.Category> = [
        .hrv, .rhr, .sleep, .steps, .exercise, .weight, .bmi
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let prefix = Bundle.main.bundleIdentifier ?? "com.dailve"
        self.key = "\(prefix).today.pinnedMetricCategories"
    }

    func load() -> [HealthMetric.Category] {
        guard let rawValues = defaults.array(forKey: key) as? [String] else {
            return Self.fallback
        }
        let normalized = Self.normalize(rawValues: rawValues)
        return normalized.isEmpty ? Self.fallback : normalized
    }

    func save(_ categories: [HealthMetric.Category]) {
        let normalized = Self.normalize(categories: categories)
        defaults.set(normalized.map(\.rawValue), forKey: key)
    }

    private static func normalize(rawValues: [String]) -> [HealthMetric.Category] {
        let decoded = rawValues.compactMap(HealthMetric.Category.init(rawValue:))
        return normalize(categories: decoded)
    }

    private static func normalize(categories: [HealthMetric.Category]) -> [HealthMetric.Category] {
        var seen = Set<HealthMetric.Category>()
        var result: [HealthMetric.Category] = []

        for category in categories where allowedCategories.contains(category) {
            guard !seen.contains(category) else { continue }
            seen.insert(category)
            result.append(category)
            if result.count == maxPinnedCount { break }
        }
        return result
    }
}
