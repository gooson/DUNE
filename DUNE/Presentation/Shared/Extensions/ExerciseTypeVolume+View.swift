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
            return category.color
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
