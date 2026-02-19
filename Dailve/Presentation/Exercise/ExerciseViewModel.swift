import Foundation
import Observation

@Observable
@MainActor
final class ExerciseViewModel {
    var healthKitWorkouts: [WorkoutSummary] = [] { didSet { invalidateCache() } }
    var manualRecords: [ExerciseRecord] = [] { didSet { invalidateCache() } }
    var isLoading = false
    var isLoadingMore = false
    var hasMoreData = true
    var errorMessage: String?

    private let workoutService: WorkoutQuerying
    private let exerciseLibrary: ExerciseLibraryQuerying

    /// Number of days per page for incremental loading.
    private static let pageSizeDays = 30

    /// The earliest date already fetched (cursor for next page).
    private var oldestFetchedDate: Date?

    init(workoutService: WorkoutQuerying? = nil, exerciseLibrary: ExerciseLibraryQuerying? = nil) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: .shared)
        self.exerciseLibrary = exerciseLibrary ?? ExerciseLibraryService.shared
    }

    private(set) var allExercises: [ExerciseListItem] = []

    // Note: didSet fires separately per property. In practice, manualRecords and
    // healthKitWorkouts are not assigned in the same run loop tick (manualRecords
    // comes from @Query, healthKitWorkouts from async fetch), so double invalidation
    // does not occur. If batch updates are needed in the future, add an
    // updateData(workouts:records:) method that sets both before a single invalidation.
    private let personalRecordStore = PersonalRecordStore.shared

    private func invalidateCache() {
        var externalWorkouts = healthKitWorkouts.filteringAppDuplicates(against: manualRecords)

        // Detect milestones and personal records
        for i in externalWorkouts.indices {
            let prTypes = personalRecordStore.updateIfNewRecords(externalWorkouts[i])
            if !prTypes.isEmpty {
                externalWorkouts[i].isPersonalRecord = true
                externalWorkouts[i].personalRecordTypes = prTypes
            }
        }

        var items: [ExerciseListItem] = []
        items.reserveCapacity(externalWorkouts.count + manualRecords.count)

        for workout in externalWorkouts {
            items.append(ExerciseListItem(
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
            ))
        }

        for record in manualRecords {
            let definition = record.exerciseDefinitionID.flatMap {
                exerciseLibrary.exercise(byID: $0)
            }
            let localizedName = definition?.localizedName
            let activityType = definition?.resolvedActivityType
                ?? WorkoutActivityType.infer(from: record.exerciseType)
                ?? .other
            let hasHKLink = record.healthKitWorkoutID.map { !$0.isEmpty } ?? false
            items.append(ExerciseListItem(
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
                primaryMuscles: record.primaryMuscles
            ))
        }

        allExercises = items.sorted { $0.date > $1.date }
    }

    func loadHealthKitWorkouts() async {
        isLoading = true
        hasMoreData = true
        oldestFetchedDate = nil

        do {
            let workouts = try await workoutService.fetchWorkouts(days: Self.pageSizeDays)
            healthKitWorkouts = workouts

            if let oldest = workouts.last?.date {
                oldestFetchedDate = oldest
            }
            // If fewer results than expected, no more data
            if workouts.isEmpty {
                hasMoreData = false
            }
        } catch {
            AppLogger.ui.error("Exercise data load failed: \(error.localizedDescription)")
            errorMessage = "Could not load workout data"
        }
        isLoading = false
    }

    /// Loads the next page of older workouts.
    func loadMoreWorkouts() async {
        guard !isLoadingMore, !isLoading, hasMoreData else { return }
        guard let cursor = oldestFetchedDate else {
            hasMoreData = false
            return
        }

        isLoadingMore = true
        let calendar = Calendar.current
        guard let pageStart = calendar.date(
            byAdding: .day, value: -Self.pageSizeDays, to: cursor
        ) else {
            isLoadingMore = false
            hasMoreData = false
            return
        }

        do {
            let moreWorkouts = try await workoutService.fetchWorkouts(
                start: pageStart, end: cursor
            )

            if moreWorkouts.isEmpty {
                hasMoreData = false
            } else {
                // Deduplicate by ID before appending
                let existingIDs = Set(healthKitWorkouts.map(\.id))
                let newWorkouts = moreWorkouts.filter { !existingIDs.contains($0.id) }
                healthKitWorkouts.append(contentsOf: newWorkouts)

                if let oldest = moreWorkouts.last?.date {
                    oldestFetchedDate = oldest
                }
            }
        } catch {
            AppLogger.ui.error("Exercise load more failed: \(error.localizedDescription)")
        }
        isLoadingMore = false
    }

}

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
}
