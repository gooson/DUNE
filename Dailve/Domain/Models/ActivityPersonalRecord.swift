import Foundation

/// Unified personal record model used by Activity screens.
/// Combines strength PRs and cardio PRs under one display shape.
struct ActivityPersonalRecord: Sendable, Hashable, Identifiable {
    enum Kind: String, Sendable, Hashable, CaseIterable {
        case strengthWeight
        case fastestPace
        case longestDistance
        case highestCalories
        case longestDuration
        case highestElevation

        var isLowerBetter: Bool {
            self == .fastestPace
        }

        var sortOrder: Int {
            switch self {
            case .strengthWeight: 0
            case .fastestPace: 1
            case .longestDistance: 2
            case .longestDuration: 3
            case .highestCalories: 4
            case .highestElevation: 5
            }
        }
    }

    enum Source: String, Sendable, Hashable {
        case healthKit
        case manual
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let value: Double
    let date: Date
    let isRecent: Bool
    let source: Source
    let workoutID: String?

    // Optional context for richer cards/detail.
    let heartRateAvg: Double?
    let heartRateMax: Double?
    let heartRateMin: Double?
    let stepCount: Double?
    let weatherTemperature: Double?
    let weatherCondition: Int?
    let weatherHumidity: Double?
    let isIndoor: Bool?

    init(
        id: String,
        kind: Kind,
        title: String,
        subtitle: String? = nil,
        value: Double,
        date: Date,
        isRecent: Bool,
        source: Source,
        workoutID: String? = nil,
        heartRateAvg: Double? = nil,
        heartRateMax: Double? = nil,
        heartRateMin: Double? = nil,
        stepCount: Double? = nil,
        weatherTemperature: Double? = nil,
        weatherCondition: Int? = nil,
        weatherHumidity: Double? = nil,
        isIndoor: Bool? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.date = date
        self.isRecent = isRecent
        self.source = source
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

extension ActivityPersonalRecord.Kind {
    init?(personalRecordType: PersonalRecordType) {
        switch personalRecordType {
        case .fastestPace: self = .fastestPace
        case .longestDistance: self = .longestDistance
        case .highestCalories: self = .highestCalories
        case .longestDuration: self = .longestDuration
        case .highestElevation: self = .highestElevation
        }
    }
}
