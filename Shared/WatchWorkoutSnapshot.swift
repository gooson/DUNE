import Foundation

/// Small payload used only by the mirrored workout and its Live Activity.
struct WatchWorkoutSnapshot: Codable, Hashable, Sendable {
    enum WorkoutKind: String, Codable, Sendable {
        case cardio, strength
    }

    enum Phase: String, Codable, Sendable {
        case running, paused, ended
    }

    var startedAt: Date
    var updatedAt: Date
    var exerciseName: String
    var elapsedSeconds: TimeInterval
    var phase: Phase
    var heartRate: Double?
    var activeCalories: Double
    var distanceMeters: Double
    /// Canonical WorkoutActivityType.iconName from the producer; absent on older Watch versions.
    var exerciseIconName: String? = nil
    /// Session category and metric availability. Absent on older Watch versions.
    var workoutKind: WorkoutKind? = nil
    var supportsDistance: Bool? = nil
    /// Live editable current-set input in kg; zero is a meaningful no-load value.
    var currentSetWeightKg: Double? = nil

    func phaseIconName(isStale: Bool) -> String {
        if isStale { return "wifi.slash" }
        switch phase {
        case .running:
            guard let exerciseIconName,
                  !exerciseIconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  exerciseIconName.count <= 100 else { return "figure" }
            return exerciseIconName
        case .paused: return "pause.fill"
        case .ended: return "checkmark"
        }
    }

    var isValid: Bool {
        startedAt.timeIntervalSince1970.isFinite
            && updatedAt.timeIntervalSince1970.isFinite
            && updatedAt >= startedAt
            && !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && exerciseName.count <= 200
            && elapsedSeconds.isFinite && (0...172_800).contains(elapsedSeconds)
            && activeCalories.isFinite && (0...100_000).contains(activeCalories)
            && distanceMeters.isFinite && (0...1_000_000).contains(distanceMeters)
            && (heartRate == nil || heartRate.map { $0.isFinite && (20...250).contains($0) } == true)
            && (currentSetWeightKg == nil || currentSetWeightKg.map { $0.isFinite && (0...500).contains($0) } == true)
    }

    /// A running system timer advances without a per-second transport update.
    var timerStartDate: Date { updatedAt.addingTimeInterval(-elapsedSeconds) }

    func isSameWorkout(as other: Self) -> Bool {
        startedAt == other.startedAt
    }

    func elapsed(at date: Date) -> TimeInterval {
        elapsedSeconds + (phase == .running ? max(0, date.timeIntervalSince(updatedAt)) : 0)
    }
}

extension WatchWorkoutSnapshot {
    private enum CodingKeys: String, CodingKey {
        case startedAt, updatedAt, exerciseName, elapsedSeconds, phase
        case heartRate, activeCalories, distanceMeters, exerciseIconName
        case workoutKind, supportsDistance, currentSetWeightKg
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        exerciseName = try values.decode(String.self, forKey: .exerciseName)
        elapsedSeconds = try values.decode(TimeInterval.self, forKey: .elapsedSeconds)
        phase = try values.decode(Phase.self, forKey: .phase)
        heartRate = try values.decodeIfPresent(Double.self, forKey: .heartRate)
        activeCalories = try values.decode(Double.self, forKey: .activeCalories)
        distanceMeters = try values.decode(Double.self, forKey: .distanceMeters)
        exerciseIconName = try values.decodeIfPresent(String.self, forKey: .exerciseIconName)
        let workoutKindRawValue = try values.decodeIfPresent(String.self, forKey: .workoutKind)
        workoutKind = workoutKindRawValue.flatMap(WorkoutKind.init(rawValue:))
        supportsDistance = try values.decodeIfPresent(Bool.self, forKey: .supportsDistance)
        currentSetWeightKg = try values.decodeIfPresent(Double.self, forKey: .currentSetWeightKg)
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(startedAt, forKey: .startedAt)
        try values.encode(updatedAt, forKey: .updatedAt)
        try values.encode(exerciseName, forKey: .exerciseName)
        try values.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try values.encode(phase, forKey: .phase)
        try values.encodeIfPresent(heartRate, forKey: .heartRate)
        try values.encode(activeCalories, forKey: .activeCalories)
        try values.encode(distanceMeters, forKey: .distanceMeters)
        try values.encodeIfPresent(exerciseIconName, forKey: .exerciseIconName)
        try values.encodeIfPresent(workoutKind?.rawValue, forKey: .workoutKind)
        try values.encodeIfPresent(supportsDistance, forKey: .supportsDistance)
        try values.encodeIfPresent(currentSetWeightKg, forKey: .currentSetWeightKg)
    }
}

/// Keeps delayed WatchConnectivity lifecycle messages from replacing newer state.
struct WatchWorkoutLifecycleOrdering {
    private(set) var latestUpdate: Date?

    mutating func accept(_ updatedAt: Date?) -> Bool {
        guard let updatedAt else { return latestUpdate == nil }
        guard updatedAt.timeIntervalSince1970.isFinite,
              latestUpdate.map({ updatedAt >= $0 }) ?? true else { return false }
        latestUpdate = updatedAt
        return true
    }
}
