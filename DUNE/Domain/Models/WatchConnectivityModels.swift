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
}

struct WatchSetData: Codable, Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    var restDuration: TimeInterval?
    let isCompleted: Bool
}

struct WatchHeartRateSample: Codable, Sendable {
    let bpm: Double
    let timestamp: Date
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
    let equipment: String?
    let cardioSecondaryUnit: String?
    let aliases: [String]?

    init(
        id: String,
        name: String,
        inputType: String,
        defaultSets: Int,
        defaultReps: Int?,
        defaultWeightKg: Double?,
        isPreferred: Bool = false,
        equipment: String?,
        cardioSecondaryUnit: String?,
        aliases: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.inputType = inputType
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeightKg = defaultWeightKg
        self.isPreferred = isPreferred
        self.equipment = equipment
        self.cardioSecondaryUnit = cardioSecondaryUnit
        self.aliases = aliases
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case inputType
        case defaultSets
        case defaultReps
        case defaultWeightKg
        case isPreferred
        case equipment
        case cardioSecondaryUnit
        case aliases
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
        equipment = try container.decodeIfPresent(String.self, forKey: .equipment)
        cardioSecondaryUnit = try container.decodeIfPresent(String.self, forKey: .cardioSecondaryUnit)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases)
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
