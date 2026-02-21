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
        case heartRate
        case sleep
        case exercise
        case steps
        case weight
        case bmi
        case bodyFat
        case leanBodyMass
        case spo2
        case respiratoryRate
        case vo2Max
        case heartRateRecovery
        case wristTemperature
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

/// Summarized sleep data for recovery modifier computation.
struct SleepSummary: Sendable {
    /// Total sleep duration in minutes (excludes awake time).
    let totalSleepMinutes: Double
    /// Deep sleep proportion (0.0...1.0) of total sleep.
    let deepSleepRatio: Double
    /// REM sleep proportion (0.0...1.0) of total sleep.
    let remSleepRatio: Double
    /// The date this sleep data corresponds to.
    let date: Date
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
    let activityType: WorkoutActivityType
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let date: Date
    /// Whether this workout was created by this app (resolved at Data layer from HealthKit source metadata).
    let isFromThisApp: Bool

    // MARK: - Rich data (populated from HKWorkout statistics/metadata)

    let heartRateAvg: Double?
    let heartRateMax: Double?
    let heartRateMin: Double?
    let averagePace: Double?        // seconds per kilometer (running/walking)
    let averageSpeed: Double?       // meters per second (cycling etc.)
    let elevationAscended: Double?  // meters
    let weatherTemperature: Double? // celsius
    let weatherCondition: Int?      // HKWeatherCondition rawValue
    let weatherHumidity: Double?    // 0-100 percent
    let isIndoor: Bool?
    let effortScore: Double?        // 1-10 (user-rated or estimated)
    let stepCount: Double?

    // MARK: - Achievement flags (set by PR/milestone detection)

    var milestoneDistance: MilestoneDistance?
    var isPersonalRecord: Bool
    var personalRecordTypes: [PersonalRecordType]

    init(
        id: String, type: String, activityType: WorkoutActivityType = .other,
        duration: TimeInterval,
        calories: Double?, distance: Double?, date: Date,
        isFromThisApp: Bool = false,
        heartRateAvg: Double? = nil, heartRateMax: Double? = nil, heartRateMin: Double? = nil,
        averagePace: Double? = nil, averageSpeed: Double? = nil,
        elevationAscended: Double? = nil,
        weatherTemperature: Double? = nil, weatherCondition: Int? = nil,
        weatherHumidity: Double? = nil,
        isIndoor: Bool? = nil,
        effortScore: Double? = nil,
        stepCount: Double? = nil,
        milestoneDistance: MilestoneDistance? = nil,
        isPersonalRecord: Bool = false,
        personalRecordTypes: [PersonalRecordType] = []
    ) {
        self.id = id
        self.type = type
        self.activityType = activityType
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.date = date
        self.isFromThisApp = isFromThisApp
        self.heartRateAvg = heartRateAvg
        self.heartRateMax = heartRateMax
        self.heartRateMin = heartRateMin
        self.averagePace = averagePace
        self.averageSpeed = averageSpeed
        self.elevationAscended = elevationAscended
        self.weatherTemperature = weatherTemperature
        self.weatherCondition = weatherCondition
        self.weatherHumidity = weatherHumidity
        self.isIndoor = isIndoor
        self.effortScore = effortScore
        self.stepCount = stepCount
        self.milestoneDistance = milestoneDistance
        self.isPersonalRecord = isPersonalRecord
        self.personalRecordTypes = personalRecordTypes
    }

    /// Whether this workout type primarily measures distance.
    var isDistanceBased: Bool {
        activityType.isDistanceBased
    }

    /// Whether the given lowercased workout type primarily measures distance (legacy).
    static func isDistanceBasedType(_ type: String) -> Bool {
        switch type {
        case "running", "cycling", "walking", "hiking", "swimming":
            return true
        default:
            return false
        }
    }
}
