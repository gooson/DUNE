import Foundation

/// Unified personal record model used by Activity screens.
/// Combines strength PRs and cardio PRs under one display shape.
struct ActivityPersonalRecord: Sendable, Hashable, Identifiable {
    enum Kind: String, Sendable, Hashable, CaseIterable {
        case estimated1RM
        case repMax
        case sessionVolume
        case strengthWeight
        case fastestPace
        case longestDistance
        case highestCalories
        case longestDuration
        case highestElevation

        var isLowerBetter: Bool {
            self == .fastestPace
        }

        var isStrengthKind: Bool {
            switch self {
            case .estimated1RM, .repMax, .sessionVolume, .strengthWeight: true
            case .fastestPace, .longestDistance, .longestDuration,
                 .highestCalories, .highestElevation: false
            }
        }

        var sortOrder: Int {
            switch self {
            case .estimated1RM: 0
            case .repMax: 1
            case .sessionVolume: 2
            case .strengthWeight: 3
            case .fastestPace: 4
            case .longestDistance: 5
            case .longestDuration: 6
            case .highestCalories: 7
            case .highestElevation: 8
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

    // Delta from previous best (nil if first record for this kind).
    let previousValue: Double?

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
        previousValue: Double? = nil,
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
        self.previousValue = previousValue
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

extension ActivityPersonalRecord {
    /// Delta from previous best. Positive means improvement.
    var deltaValue: Double? {
        guard let prev = previousValue else { return nil }
        return kind.isLowerBetter ? prev - value : value - prev
    }

    /// Formatted delta string (e.g., "+5.2" or "-0:12").
    var formattedDelta: String? {
        guard let delta = deltaValue, abs(delta) > 0.01 else { return nil }
        let sign = delta > 0 ? "+" : ""
        switch kind {
        case .fastestPace:
            let totalSeconds = Int(abs(delta))
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(sign)\(minutes)'\(String(format: "%02d", seconds))\""
        case .longestDistance:
            return "\(sign)\((delta / 1000.0).formattedWithSeparator(fractionDigits: 1))km"
        case .longestDuration:
            return "\(sign)\(TimeInterval(abs(delta)).formattedDuration())"
        default:
            return "\(sign)\(delta.formattedWithSeparator())"
        }
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
