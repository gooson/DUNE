import Foundation

enum ExerciseMixKind: Sendable, Equatable {
    case strength
    case cardio
    case other
}

struct ExerciseMixEntry: Sendable {
    let id: String
    let linkedWorkoutID: String?
    let isHealthKit: Bool
    let date: Date
    let name: String
    let kind: ExerciseMixKind
    let primaryMuscles: [MuscleGroup]
    let completedSets: Int
    let durationMinutes: Double?
    let distanceKm: Double?
    var dedupName: String? = nil
}

struct ExerciseMixSummary: Sendable {
    struct Week: Sendable, Identifiable {
        let index: Int
        let start: Date
        let strength: Int
        let cardio: Int
        let other: Int
        var id: Int { index }
        var total: Int { strength + cardio + other }
    }

    struct MuscleShare: Sendable, Identifiable {
        let muscle: MuscleGroup
        let sets: Double
        let fraction: Double
        var id: MuscleGroup { muscle }
    }

    struct CardioType: Sendable, Identifiable {
        let name: String
        let count: Int
        let durationMinutes: Double?
        let distanceKm: Double?
        var id: String { name }
    }

    let start: Date
    let end: Date
    let strength: Int
    let cardio: Int
    let other: Int
    let weeks: [Week]
    let muscles: [MuscleShare]
    let unattributedSets: Int
    let cardioTypes: [CardioType]
    let frequencies: [ExerciseFrequency]
    var total: Int { strength + cardio + other }

    static func empty(asOf date: Date = .now, calendar: Calendar = .current) -> Self {
        ExerciseMixService.analyze([], asOf: date, calendar: calendar)
    }
}
