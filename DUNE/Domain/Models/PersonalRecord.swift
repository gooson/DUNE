import Foundation

/// A single personal record entry for a specific workout activity type.
struct PersonalRecord: Codable, Sendable {
    let type: PersonalRecordType
    let value: Double
    let date: Date
    let workoutID: String

    // Optional HealthKit context for richer PR display.
    let heartRateAvg: Double?
    let heartRateMax: Double?
    let heartRateMin: Double?
    let stepCount: Double?
    let weatherTemperature: Double?
    let weatherCondition: Int?
    let weatherHumidity: Double?
    let isIndoor: Bool?

    init(
        type: PersonalRecordType,
        value: Double,
        date: Date,
        workoutID: String,
        heartRateAvg: Double? = nil,
        heartRateMax: Double? = nil,
        heartRateMin: Double? = nil,
        stepCount: Double? = nil,
        weatherTemperature: Double? = nil,
        weatherCondition: Int? = nil,
        weatherHumidity: Double? = nil,
        isIndoor: Bool? = nil
    ) {
        self.type = type
        self.value = value
        self.date = date
        self.workoutID = workoutID
        self.heartRateAvg = heartRateAvg
        self.heartRateMax = heartRateMax
        self.heartRateMin = heartRateMin
        self.stepCount = stepCount
        self.weatherTemperature = weatherTemperature
        self.weatherCondition = weatherCondition
        self.weatherHumidity = weatherHumidity
        self.isIndoor = isIndoor
    }
}

/// Training Load data point for a single day.
struct TrainingLoad: Identifiable, Sendable {
    let id: Date
    let date: Date
    let load: Double
    let source: LoadSource

    enum LoadSource: String, Codable, Sendable {
        case effort      // Apple Workout Effort Score
        case rpe         // User-entered RPE
        case trimp       // HR-based TRIMP calculation
    }
}

// MARK: - Workout Rewards

/// Reward event type emitted when a workout triggers an achievement.
enum WorkoutRewardEventKind: String, Codable, Sendable, Hashable {
    case milestone
    case personalRecord
    case badgeUnlocked
    case levelUp

    /// Higher value means higher notification priority.
    var priority: Int {
        switch self {
        case .milestone: 1
        case .personalRecord: 2
        case .badgeUnlocked: 3
        case .levelUp: 4
        }
    }
}

/// Single achievement record stored for reward history and notification selection.
struct WorkoutRewardEvent: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let workoutID: String
    let activityTypeRawValue: String
    let date: Date
    let kind: WorkoutRewardEventKind
    let title: String
    let detail: String
    let pointsAwarded: Int
    let levelAfterEvent: Int?
}

/// Aggregated reward status used by Activity PR and history screens.
struct WorkoutRewardSummary: Codable, Sendable, Hashable {
    let level: Int
    let totalPoints: Int
    let badgeCount: Int

    static let empty = WorkoutRewardSummary(level: 1, totalPoints: 0, badgeCount: 0)
}

/// Result of evaluating a workout against reward rules.
struct WorkoutRewardOutcome: Sendable {
    let events: [WorkoutRewardEvent]
    let representativeEvent: WorkoutRewardEvent?
    let summary: WorkoutRewardSummary
}
