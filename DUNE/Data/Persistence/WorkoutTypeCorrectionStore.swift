import Foundation

/// Persists user-corrected display titles for HealthKit workout entries.
///
/// Backed entirely by `UserDefaults`, so instances do not hold mutable in-memory state.
final class WorkoutTypeCorrectionStore: @unchecked Sendable {
    static let shared = WorkoutTypeCorrectionStore()

    private let userDefaults: UserDefaults
    private let storageKey = "workout.type.corrections.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func correctedTitle(for workoutID: String) -> String? {
        guard !workoutID.isEmpty else { return nil }
        let map = correctionMap()
        guard let raw = map[workoutID] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func setCorrectedTitle(_ title: String?, for workoutID: String) {
        guard !workoutID.isEmpty else { return }
        var map = correctionMap()

        if let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                map.removeValue(forKey: workoutID)
            } else {
                map[workoutID] = String(trimmed.prefix(100))
            }
        } else {
            map.removeValue(forKey: workoutID)
        }

        userDefaults.set(map, forKey: storageKey)
    }

    private func correctionMap() -> [String: String] {
        userDefaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }
}
