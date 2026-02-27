import SwiftUI

extension ExerciseTypeVolume {
    /// Resolves the display color based on the activity category.
    var color: Color {
        // Try to resolve as WorkoutActivityType first (exact per-type color)
        if let activityType = WorkoutActivityType(rawValue: typeKey) {
            return activityType.color
        }
        // Fallback: resolve category raw value
        if let category = ActivityCategory(rawValue: categoryRawValue) {
            switch category {
            case .cardio: return DS.Color.activityCardio
            case .strength: return DS.Color.activityStrength
            case .mindBody: return DS.Color.activityMindBody
            case .dance: return DS.Color.activityDance
            case .combat: return DS.Color.activityCombat
            case .sports: return DS.Color.activitySports
            case .water: return DS.Color.activityWater
            case .winter: return DS.Color.activityWinter
            case .outdoor: return DS.Color.activityOutdoor
            case .multiSport: return DS.Color.activityCardio
            case .other: return DS.Color.activityOther
            }
        }
        return DS.Color.activityOther
    }

    /// Resolves the SF Symbol icon name.
    var iconName: String {
        if let activityType = WorkoutActivityType(rawValue: typeKey) {
            return activityType.iconName
        }
        return "dumbbell.fill"
    }

    /// Resolves the Equipment from the raw value, if available.
    var equipment: Equipment? {
        equipmentRawValue.flatMap { Equipment(rawValue: $0) }
    }
}
