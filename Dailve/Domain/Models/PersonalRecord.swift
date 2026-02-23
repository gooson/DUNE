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
