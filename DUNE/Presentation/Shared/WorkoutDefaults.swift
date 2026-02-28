import Foundation

/// App-level workout constants shared across Presentation layer.
/// Reads user-configured values from WorkoutSettingsStore with sensible fallbacks.
/// Prevents cross-ViewModel coupling for common workout parameters (Correction #73).
enum WorkoutDefaults {
    /// Default number of sets for a new workout session
    static var setCount: Int {
        WorkoutSettingsStore.shared.setCount
    }

    /// Default rest between sets in seconds
    static var restSeconds: TimeInterval {
        WorkoutSettingsStore.shared.restSeconds
    }

    /// Default body weight for calorie estimation (kg)
    static var bodyWeightKg: Double {
        WorkoutSettingsStore.shared.bodyWeightKg
    }
}
