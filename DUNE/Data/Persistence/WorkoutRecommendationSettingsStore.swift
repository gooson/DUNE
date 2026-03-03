import Foundation

/// Persists recommendation context, available equipment, and hidden exercises in UserDefaults.
/// Key prefix uses bundle identifier for test/production isolation.
final class WorkoutRecommendationSettingsStore: @unchecked Sendable {
    static let shared = WorkoutRecommendationSettingsStore()

    private let defaults: UserDefaults
    private let prefix: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.prefix = Bundle.main.bundleIdentifier ?? "com.dailve"
    }

    private var contextKey: String { "\(prefix).recommendation.context" }
    private var gymEquipmentKey: String { "\(prefix).recommendation.equipment.gym" }
    private var homeEquipmentKey: String { "\(prefix).recommendation.equipment.home" }
    private var excludedExerciseIDsKey: String { "\(prefix).recommendation.excludedExerciseIDs" }

    var context: WorkoutRecommendationContext {
        get {
            guard let raw = defaults.string(forKey: contextKey),
                  let context = WorkoutRecommendationContext(rawValue: raw) else {
                return .gym
            }
            return context
        }
        set {
            defaults.set(newValue.rawValue, forKey: contextKey)
        }
    }

    var excludedExerciseIDs: Set<String> {
        get {
            guard let values = defaults.array(forKey: excludedExerciseIDsKey) as? [String] else {
                return []
            }
            let trimmed = values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return Set(trimmed)
        }
        set {
            let sorted = Array(
                Set(newValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty })
            ).sorted()
            defaults.set(sorted, forKey: excludedExerciseIDsKey)
        }
    }

    func isExerciseExcluded(_ exerciseID: String) -> Bool {
        excludedExerciseIDs.contains(exerciseID)
    }

    func setExerciseExcluded(_ excluded: Bool, exerciseID: String) {
        let trimmedID = exerciseID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }

        var current = excludedExerciseIDs
        if excluded {
            current.insert(trimmedID)
        } else {
            current.remove(trimmedID)
        }
        excludedExerciseIDs = current
    }

    func availableEquipment(for context: WorkoutRecommendationContext) -> Set<Equipment> {
        let key = equipmentKey(for: context)
        let fallback = context.defaultEquipment

        guard let rawValues = defaults.array(forKey: key) as? [String] else {
            return fallback
        }

        let resolved = Set(rawValues.compactMap { Equipment(rawValue: $0) })
            .subtracting([.other])

        return resolved.isEmpty ? fallback : resolved
    }

    func setEquipmentAvailable(
        _ isAvailable: Bool,
        equipment: Equipment,
        for context: WorkoutRecommendationContext
    ) {
        guard equipment != .other else { return }

        var current = availableEquipment(for: context)
        if isAvailable {
            current.insert(equipment)
        } else {
            current.remove(equipment)
        }
        saveEquipment(current, for: context)
    }

    private func equipmentKey(for context: WorkoutRecommendationContext) -> String {
        switch context {
        case .gym:
            return gymEquipmentKey
        case .home:
            return homeEquipmentKey
        }
    }

    private func saveEquipment(_ equipmentSet: Set<Equipment>, for context: WorkoutRecommendationContext) {
        var sanitized = Set(equipmentSet.filter { $0 != .other })
        if sanitized.isEmpty {
            sanitized.insert(.bodyweight)
        }

        let rawValues = sanitized.map(\.rawValue).sorted()
        defaults.set(rawValues, forKey: equipmentKey(for: context))
    }
}
