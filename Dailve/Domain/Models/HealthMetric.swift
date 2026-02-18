import Foundation

struct HealthMetric: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let value: Double
    let unit: String
    let change: Double?
    let date: Date
    let category: Category
    var isHistorical: Bool = false
    var iconOverride: String? = nil

    enum Category: String, Sendable, CaseIterable {
        case hrv
        case rhr
        case sleep
        case exercise
        case steps
        case weight
        case bmi
    }

    var changeSignificance: Double {
        guard let change else { return 0 }
        return abs(change)
    }
}

struct SleepStage: Sendable {
    let stage: Stage
    let duration: TimeInterval
    let startDate: Date
    let endDate: Date

    enum Stage: String, Sendable {
        case awake
        case core
        case deep
        case rem

        var label: String {
            switch self {
            case .awake: "Awake"
            case .core: "Core"
            case .deep: "Deep"
            case .rem: "REM"
            }
        }
    }
}

struct HRVSample: Sendable {
    let value: Double
    let date: Date
}

/// Heart rate sample point for workout timeline chart.
struct HeartRateSample: Sendable {
    let bpm: Double
    let date: Date
}

/// Aggregated heart rate data for a workout session.
struct HeartRateSummary: Sendable {
    let average: Double
    let max: Double
    let min: Double
    let samples: [HeartRateSample]

    var isEmpty: Bool { samples.isEmpty }
}

struct WorkoutSummary: Identifiable, Sendable {
    let id: String
    let type: String
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let date: Date
    /// Whether this workout was created by this app (resolved at Data layer from HealthKit source metadata).
    let isFromThisApp: Bool

    // Explicit init provides default `false` for isFromThisApp, supporting backward
    // compatibility with existing call sites that don't specify app ownership.
    init(
        id: String, type: String, duration: TimeInterval,
        calories: Double?, distance: Double?, date: Date,
        isFromThisApp: Bool = false
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.date = date
        self.isFromThisApp = isFromThisApp
    }

    /// Whether this workout type primarily measures distance.
    var isDistanceBased: Bool {
        Self.isDistanceBasedType(type.lowercased())
    }

    /// Whether the given lowercased workout type primarily measures distance.
    static func isDistanceBasedType(_ type: String) -> Bool {
        switch type {
        case "running", "cycling", "walking", "hiking", "swimming":
            return true
        default:
            return false
        }
    }

    /// Maps workout type name to SF Symbol.
    static func iconName(for type: String) -> String {
        switch type.lowercased() {
        case "running":     "figure.run"
        case "walking":     "figure.walk"
        case "cycling":     "figure.outdoor.cycle"
        case "swimming":    "figure.pool.swim"
        case "hiking":      "figure.hiking"
        case "yoga":        "figure.yoga"
        case "strength", "strength training": "dumbbell.fill"
        case "dance", "dancing": "figure.dance"
        case "elliptical":  "figure.elliptical"
        case "rowing":      "figure.rower"
        case "stair stepper", "stairs": "figure.stairs"
        case "pilates":     "figure.pilates"
        case "martial arts": "figure.martial.arts"
        case "cooldown":    "figure.cooldown"
        case "core training": "figure.core.training"
        case "stretching", "flexibility": "figure.flexibility"
        default:            "figure.mixed.cardio"
        }
    }
}
