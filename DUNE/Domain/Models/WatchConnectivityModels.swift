import Foundation

/// Workout state sent from iPhone to Watch for live session UI.
struct WatchWorkoutState: Codable, Sendable {
    let exerciseName: String
    let exerciseID: String
    let currentSet: Int
    let totalSets: Int
    let targetWeight: Double?
    let targetReps: Int?
    let isActive: Bool
}

/// Workout payload sent from Watch to iPhone for persistence.
struct WatchWorkoutUpdate: Codable, Sendable {
    let exerciseID: String
    let exerciseName: String
    var completedSets: [WatchSetData]
    let startTime: Date
    let endTime: Date?
    var heartRateSamples: [WatchHeartRateSample]
    var rpe: Int?
    var healthKitWorkoutID: String?
    var calories: Double?
    var calorieSourceRaw: String?
}

struct WatchSetData: Codable, Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    var restDuration: TimeInterval?
    let isCompleted: Bool
    var rpe: Double?
}

struct WatchHeartRateSample: Codable, Sendable {
    let bpm: Double
    let timestamp: Date
}

/// Compact per-set strength procedure snapshot used for Quick Start replay.
struct WatchProcedureSetSnapshot: Codable, Sendable, Hashable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
}

/// Compact exercise metadata used by Watch UI.
struct WatchExerciseInfo: Codable, Sendable {
    let id: String
    let name: String
    let inputType: String
    let defaultSets: Int
    let defaultReps: Int?
    let defaultWeightKg: Double?
    let isPreferred: Bool
    let lastUsedAt: Date?
    let usageCount: Int
    let equipment: String?
    let cardioSecondaryUnit: String?
    let aliases: [String]?
    let procedureSets: [WatchProcedureSetSnapshot]?
    let procedureUpdatedAt: Date?
    let progressionIncrementKg: Double?
    let metValue: Double?

    init(
        id: String,
        name: String,
        inputType: String,
        defaultSets: Int,
        defaultReps: Int?,
        defaultWeightKg: Double?,
        isPreferred: Bool = false,
        lastUsedAt: Date? = nil,
        usageCount: Int = 0,
        equipment: String?,
        cardioSecondaryUnit: String?,
        aliases: [String]? = nil,
        procedureSets: [WatchProcedureSetSnapshot]? = nil,
        procedureUpdatedAt: Date? = nil,
        progressionIncrementKg: Double? = nil,
        metValue: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.inputType = inputType
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeightKg = defaultWeightKg
        self.isPreferred = isPreferred
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
        self.equipment = equipment
        self.cardioSecondaryUnit = cardioSecondaryUnit
        self.aliases = aliases
        self.procedureSets = procedureSets
        self.procedureUpdatedAt = procedureUpdatedAt
        self.progressionIncrementKg = progressionIncrementKg
        self.metValue = metValue
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case inputType
        case defaultSets
        case defaultReps
        case defaultWeightKg
        case isPreferred
        case lastUsedAt
        case usageCount
        case equipment
        case cardioSecondaryUnit
        case aliases
        case procedureSets
        case procedureUpdatedAt
        case progressionIncrementKg
        case metValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        inputType = try container.decode(String.self, forKey: .inputType)
        defaultSets = try container.decode(Int.self, forKey: .defaultSets)
        defaultReps = try container.decodeIfPresent(Int.self, forKey: .defaultReps)
        defaultWeightKg = try container.decodeIfPresent(Double.self, forKey: .defaultWeightKg)
        isPreferred = try container.decodeIfPresent(Bool.self, forKey: .isPreferred) ?? false
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        equipment = try container.decodeIfPresent(String.self, forKey: .equipment)
        cardioSecondaryUnit = try container.decodeIfPresent(String.self, forKey: .cardioSecondaryUnit)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases)
        procedureSets = try container.decodeIfPresent([WatchProcedureSetSnapshot].self, forKey: .procedureSets)
        procedureUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .procedureUpdatedAt)
        progressionIncrementKg = try container.decodeIfPresent(Double.self, forKey: .progressionIncrementKg)
        metValue = try container.decodeIfPresent(Double.self, forKey: .metValue)
    }
}

/// Daily posture monitoring summary sent from Watch to iPhone via WatchConnectivity.
struct DailyPostureSummary: Sendable, Codable, Equatable {
    let sedentaryMinutes: Int
    let walkingMinutes: Int
    let averageGaitScore: Int?
    let stretchRemindersTriggered: Int
    let date: Date
    /// Whether posture monitoring is enabled on Watch. Defaults to `true` for backward compatibility.
    let isMonitoringEnabled: Bool

    init(
        sedentaryMinutes: Int,
        walkingMinutes: Int,
        averageGaitScore: Int?,
        stretchRemindersTriggered: Int,
        date: Date,
        isMonitoringEnabled: Bool = true
    ) {
        self.sedentaryMinutes = sedentaryMinutes
        self.walkingMinutes = walkingMinutes
        self.averageGaitScore = averageGaitScore
        self.stretchRemindersTriggered = stretchRemindersTriggered
        self.date = date
        self.isMonitoringEnabled = isMonitoringEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sedentaryMinutes = try container.decode(Int.self, forKey: .sedentaryMinutes)
        walkingMinutes = try container.decode(Int.self, forKey: .walkingMinutes)
        averageGaitScore = try container.decodeIfPresent(Int.self, forKey: .averageGaitScore)
        stretchRemindersTriggered = try container.decode(Int.self, forKey: .stretchRemindersTriggered)
        date = try container.decode(Date.self, forKey: .date)
        isMonitoringEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMonitoringEnabled) ?? true
    }

    /// Whether all data counters are zero (no activity detected — likely watch not worn).
    var hasNoActivityData: Bool {
        sedentaryMinutes == 0 && walkingMinutes == 0 && stretchRemindersTriggered == 0 && averageGaitScore == nil
    }
}

/// Shared minute-formatting utility for posture UI components (Watch + iOS).
enum PostureFormatting {
    static func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "\(minutes)min")
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return String(localized: "\(hours)h")
        }
        return String(localized: "\(hours)h \(mins)min")
    }
}

/// Lightweight workout template payload sent from iPhone to Watch.
/// Used as a fallback sync path when CloudKit template propagation is delayed/disabled.
struct WatchWorkoutTemplateInfo: Codable, Sendable {
    let id: UUID
    let name: String
    let entries: [TemplateEntry]
    let updatedAt: Date
}
