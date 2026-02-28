import Foundation

/// Persists global workout settings (rest time, set count, body weight).
/// Uses UserDefaults with bundle identifier prefix for environment isolation (Correction #76).
final class WorkoutSettingsStore: @unchecked Sendable {
    static let shared = WorkoutSettingsStore()

    private let defaults: UserDefaults
    private let prefix: String

    // MARK: - Default Fallbacks

    static let defaultRestSeconds: TimeInterval = 90
    static let defaultSetCount: Int = 5
    static let defaultBodyWeightKg: Double = 70.0

    // MARK: - Validation Ranges

    static let restSecondsRange: ClosedRange<TimeInterval> = 15...600
    static let setCountRange: ClosedRange<Int> = 1...20
    static let bodyWeightRange: ClosedRange<Double> = 20...500

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.prefix = Bundle.main.bundleIdentifier ?? "com.dailve"
    }

    // MARK: - Keys

    private var restSecondsKey: String { "\(prefix).settings.restSeconds" }
    private var setCountKey: String { "\(prefix).settings.setCount" }
    private var bodyWeightKey: String { "\(prefix).settings.bodyWeightKg" }

    // MARK: - Rest Seconds

    var restSeconds: TimeInterval {
        get {
            let value = defaults.double(forKey: restSecondsKey)
            guard value > 0 else { return Self.defaultRestSeconds }
            return value.clamped(to: Self.restSecondsRange)
        }
        set {
            defaults.set(newValue.clamped(to: Self.restSecondsRange), forKey: restSecondsKey)
        }
    }

    // MARK: - Set Count

    var setCount: Int {
        get {
            let value = defaults.integer(forKey: setCountKey)
            guard value > 0 else { return Self.defaultSetCount }
            return value.clamped(to: Self.setCountRange)
        }
        set {
            defaults.set(newValue.clamped(to: Self.setCountRange), forKey: setCountKey)
        }
    }

    // MARK: - Body Weight

    var bodyWeightKg: Double {
        get {
            let value = defaults.double(forKey: bodyWeightKey)
            guard value > 0 else { return Self.defaultBodyWeightKg }
            return value.clamped(to: Self.bodyWeightRange)
        }
        set {
            defaults.set(newValue.clamped(to: Self.bodyWeightRange), forKey: bodyWeightKey)
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        defaults.removeObject(forKey: restSecondsKey)
        defaults.removeObject(forKey: setCountKey)
        defaults.removeObject(forKey: bodyWeightKey)
    }
}

// MARK: - Clamped Helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
