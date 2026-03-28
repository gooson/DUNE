import Foundation

// MARK: - WorkoutSet Volume Calculation

extension Array where Element: WorkoutSetVolumeProviding {
    /// Maximum allowed training volume per snapshot (physical sanity bound).
    static var maxTrainingVolume: Double { 999_999 }

    /// Sum of weight × reps across all completed sets, capped at `maxTrainingVolume`.
    /// Returns nil if zero (bodyweight or no data).
    func trainingVolume() -> Double? {
        let raw = reduce(0.0) { total, set in
            guard set.isVolumeCompleted else { return total }
            let w = set.volumeWeight
            let r = set.volumeReps
            guard w > 0, r > 0, w.isFinite else { return total }
            return total + w * r
        }
        let capped = Swift.min(raw, Self.maxTrainingVolume)
        return capped > 0 ? capped : nil
    }
}

/// Protocol to allow both WorkoutSet (SwiftData) and test stubs to participate in volume calculation.
protocol WorkoutSetVolumeProviding {
    var isVolumeCompleted: Bool { get }
    var volumeWeight: Double { get }
    var volumeReps: Double { get }
}

extension WorkoutSet: WorkoutSetVolumeProviding {
    var isVolumeCompleted: Bool { isCompleted }
    var volumeWeight: Double { weight ?? 0 }
    var volumeReps: Double { Double(reps ?? 0) }
}

extension ExerciseRecord {
    /// Total training volume (weight × reps) from completed sets.
    var totalVolume: Double {
        (sets ?? []).filter(\.isCompleted).trainingVolume() ?? 0
    }

    /// Equipment raw value resolved from stored field, falling back to ExerciseLibrary.
    /// Older records may have nil `equipmentRaw` — this resolves from the definition.
    var resolvedEquipmentRaw: String? {
        if let raw = equipmentRaw { return raw }
        guard let defID = exerciseDefinitionID else { return nil }
        return ExerciseLibraryService.shared.exercise(byID: defID)?.equipment.rawValue
    }
}
