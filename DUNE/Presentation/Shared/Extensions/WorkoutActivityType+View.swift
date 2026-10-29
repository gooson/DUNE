import SwiftUI

extension WorkoutActivityType {

    /// Category-based color for the activity type (Desert Horizon palette).
    var color: Color { category.color }
}

extension ActivityCategory {
    /// Desert Horizon palette color for the category.
    var color: Color {
        switch self {
        case .cardio: DS.Color.activityCardio
        case .strength: DS.Color.activityStrength
        case .mindBody: DS.Color.activityMindBody
        case .dance: DS.Color.activityDance
        case .combat: DS.Color.activityCombat
        case .sports: DS.Color.activitySports
        case .water: DS.Color.activityWater
        case .winter: DS.Color.activityWinter
        case .outdoor: DS.Color.activityOutdoor
        case .multiSport: DS.Color.activityCardio
        case .other: DS.Color.activityOther
        }
    }

    /// Localized display name for the category.
    var displayName: String {
        switch self {
        case .cardio: String(localized: "Cardio")
        case .strength: String(localized: "Strength")
        case .mindBody: String(localized: "Mind & Body")
        case .dance: String(localized: "Dance")
        case .combat: String(localized: "Combat")
        case .sports: String(localized: "Sports")
        case .water: String(localized: "Water")
        case .winter: String(localized: "Winter")
        case .outdoor: String(localized: "Outdoor")
        case .multiSport: String(localized: "Multi Sport")
        case .other: String(localized: "Other")
        }
    }
}

extension MilestoneDistance {
    /// SF Symbol for the milestone badge.
    var iconName: String { "medal.fill" }

    /// Badge color.
    var color: Color {
        switch self {
        case .fiveK: DS.Color.activity
        case .tenK: .blue
        case .halfMarathon: .purple
        case .marathon: .orange
        }
    }
}

extension PersonalRecordType {
    /// Localized display name.
    var displayName: String {
        switch self {
        case .fastestPace: String(localized: "Fastest Pace")
        case .longestDistance: String(localized: "Longest Distance")
        case .highestCalories: String(localized: "Highest Calories")
        case .longestDuration: String(localized: "Longest Duration")
        case .highestElevation: String(localized: "Highest Elevation")
        }
    }

    /// SF Symbol for the record type.
    var iconName: String {
        switch self {
        case .fastestPace: "speedometer"
        case .longestDistance: "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .highestCalories: "flame.fill"
        case .longestDuration: "timer"
        case .highestElevation: "mountain.2.fill"
        }
    }
}

extension ActivityPersonalRecord.Kind {
    var displayName: String {
        switch self {
        case .estimated1RM: String(localized: "Est. 1RM")
        case .repMax: String(localized: "Rep Max")
        case .sessionVolume: String(localized: "Session Volume")
        case .strengthWeight: String(localized: "Strength Weight")
        case .fastestPace: String(localized: "Fastest Pace")
        case .longestDistance: String(localized: "Longest Distance")
        case .highestCalories: String(localized: "Highest Calories")
        case .longestDuration: String(localized: "Longest Duration")
        case .highestElevation: String(localized: "Highest Elevation")
        }
    }

    var iconName: String {
        switch self {
        case .estimated1RM: "trophy.fill"
        case .repMax: "scalemass.fill"
        case .sessionVolume: "chart.bar.fill"
        case .strengthWeight: "dumbbell.fill"
        case .fastestPace: "speedometer"
        case .longestDistance: "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .highestCalories: "flame.fill"
        case .longestDuration: "timer"
        case .highestElevation: "mountain.2.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .estimated1RM: .yellow
        case .repMax: .orange
        case .sessionVolume: .purple
        case .strengthWeight: .orange
        case .fastestPace: DS.Color.activity
        case .longestDistance: DS.Color.activity
        case .highestCalories: .orange
        case .longestDuration: DS.Color.fitness
        case .highestElevation: .green
        }
    }
}

extension ActivityPersonalRecord.Kind {
    /// Unit label for this PR kind (e.g. "kg", "/km"). nil for duration.
    var unitLabel: String? {
        switch self {
        case .estimated1RM, .repMax, .sessionVolume, .strengthWeight: "kg"
        case .fastestPace: "/km"
        case .longestDistance: "km"
        case .highestCalories: "kcal"
        case .longestDuration: nil
        case .highestElevation: "m"
        }
    }
}

extension ActivityPersonalRecord {
    /// Formatted primary value text for display.
    var formattedValue: String {
        switch kind {
        case .estimated1RM, .repMax, .strengthWeight, .sessionVolume:
            return value.formattedWithSeparator()
        case .fastestPace:
            let totalSeconds = Int(value)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes)'\(String(format: "%02d", seconds))\""
        case .longestDistance:
            let km = value / 1000.0
            return km.formattedWithSeparator(fractionDigits: km >= 10 ? 1 : 2)
        case .highestCalories:
            return value.formattedWithSeparator()
        case .longestDuration:
            return TimeInterval(value).formattedDuration()
        case .highestElevation:
            return value.formattedWithSeparator()
        }
    }

    /// Presentation-safe localized title for workout-type records.
    /// Falls back to the original title for custom/manual exercise names.
    var localizedTitle: String {
        WorkoutActivityType.localizedDisplayName(forStoredTitle: title) ?? title
    }
}

extension WorkoutSummary {
    /// Presentation-safe title for HealthKit workouts.
    /// Legacy activity names are localized, while custom metadata titles are preserved.
    var localizedTitle: String {
        localizedTitle(using: .shared)
    }

    func localizedTitle(using correctionStore: WorkoutTypeCorrectionStore = .shared) -> String {
        if let corrected = correctionStore.correctedTitle(for: id) {
            return WorkoutActivityType.localizedDisplayName(
                forStoredTitle: corrected, preferredActivity: activityType
            ) ?? corrected
        }
        if let localized = WorkoutActivityType.localizedDisplayName(forStoredTitle: type, preferredActivity: activityType) {
            return localized
        }
        // type that differs from activityType.typeName is a custom exercise name
        // from HealthKit metadata (e.g. "Bench Press") — preserve it.
        // When type == activityType.typeName, localizedDisplayName above already matched.
        return type
    }
}
