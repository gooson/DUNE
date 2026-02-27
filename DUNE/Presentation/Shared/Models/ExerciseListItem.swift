import Foundation

/// Shared Presentation DTO for workout list items.
/// Used by both `ExerciseView` (full) and `ExerciseListSection` (compact) via `UnifiedWorkoutRow`.
struct ExerciseListItem: Identifiable {
    let id: String
    let type: String
    let localizedType: String?
    let activityType: WorkoutActivityType
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let date: Date
    let source: Source
    let completedSets: [WorkoutSet]
    let exerciseDefinitionID: String?
    let isLinkedToHealthKit: Bool
    let primaryMuscles: [MuscleGroup]
    let equipment: Equipment?

    // Rich data for HealthKit workouts
    let heartRateAvg: Double?
    let averagePace: Double?
    let elevationAscended: Double?
    let milestoneDistance: MilestoneDistance?
    let isPersonalRecord: Bool
    let personalRecordTypes: [PersonalRecordType]

    /// The original WorkoutSummary for navigation to detail view (HealthKit-only items).
    let workoutSummary: WorkoutSummary?

    init(
        id: String, type: String, localizedType: String? = nil,
        activityType: WorkoutActivityType = .other,
        duration: TimeInterval,
        calories: Double?, distance: Double?, date: Date,
        source: Source, completedSets: [WorkoutSet] = [],
        exerciseDefinitionID: String? = nil,
        isLinkedToHealthKit: Bool = false,
        primaryMuscles: [MuscleGroup] = [],
        equipment: Equipment? = nil,
        heartRateAvg: Double? = nil,
        averagePace: Double? = nil,
        elevationAscended: Double? = nil,
        milestoneDistance: MilestoneDistance? = nil,
        isPersonalRecord: Bool = false,
        personalRecordTypes: [PersonalRecordType] = [],
        workoutSummary: WorkoutSummary? = nil
    ) {
        self.id = id
        self.type = type
        self.localizedType = localizedType
        self.activityType = activityType
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.date = date
        self.source = source
        self.completedSets = completedSets
        self.exerciseDefinitionID = exerciseDefinitionID
        self.isLinkedToHealthKit = isLinkedToHealthKit
        self.primaryMuscles = primaryMuscles
        self.equipment = equipment
        self.heartRateAvg = heartRateAvg
        self.averagePace = averagePace
        self.elevationAscended = elevationAscended
        self.milestoneDistance = milestoneDistance
        self.isPersonalRecord = isPersonalRecord
        self.personalRecordTypes = personalRecordTypes
        self.workoutSummary = workoutSummary
    }

    enum Source {
        case healthKit
        case manual
    }

    /// Resolved display name with localization priority:
    /// 1. localizedType (exercise library Korean name) — manual records only
    /// 2. activityType.displayName (WorkoutActivityType Korean name) — unless `.other`
    /// 3. type (raw string) — final fallback
    var displayName: String {
        if let localized = localizedType, !localized.isEmpty {
            return localized
        }
        if activityType != .other {
            return activityType.displayName
        }
        return type
    }

    var formattedDuration: String {
        guard duration.isFinite, duration >= 0 else { return "0 min" }
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }

    var setSummary: String? {
        completedSets.setSummary()
    }

    // MARK: - Factory Methods

    /// Creates an `ExerciseListItem` from a manual `ExerciseRecord`.
    /// Single source of truth for the record→DTO mapping — used by both ExerciseViewModel and ExerciseListSection.
    static func fromManualRecord(
        _ record: ExerciseRecord,
        library: ExerciseLibraryQuerying
    ) -> ExerciseListItem {
        let definition = record.exerciseDefinitionID.flatMap {
            library.exercise(byID: $0)
        }
        let localizedName = definition?.localizedName
        let activityType = definition?.resolvedActivityType
            ?? WorkoutActivityType.infer(from: record.exerciseType)
            ?? .other
        let hasHKLink = record.healthKitWorkoutID.map { !$0.isEmpty } ?? false
        return ExerciseListItem(
            id: record.id.uuidString,
            type: record.exerciseType,
            localizedType: localizedName,
            activityType: activityType,
            duration: record.duration,
            calories: record.bestCalories,
            distance: record.distance,
            date: record.date,
            source: .manual,
            completedSets: record.completedSets,
            exerciseDefinitionID: record.exerciseDefinitionID,
            isLinkedToHealthKit: hasHKLink,
            primaryMuscles: record.primaryMuscles,
            equipment: definition?.equipment
        )
    }

    /// Creates an `ExerciseListItem` from a HealthKit `WorkoutSummary`.
    static func fromWorkoutSummary(_ workout: WorkoutSummary) -> ExerciseListItem {
        ExerciseListItem(
            id: workout.id,
            type: workout.type,
            activityType: workout.activityType,
            duration: workout.duration,
            calories: workout.calories,
            distance: workout.distance,
            date: workout.date,
            source: .healthKit,
            heartRateAvg: workout.heartRateAvg,
            averagePace: workout.averagePace,
            elevationAscended: workout.elevationAscended,
            milestoneDistance: workout.milestoneDistance,
            isPersonalRecord: workout.isPersonalRecord,
            personalRecordTypes: workout.personalRecordTypes,
            workoutSummary: workout
        )
    }
}
