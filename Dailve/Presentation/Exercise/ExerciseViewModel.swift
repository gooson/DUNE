import Foundation
import Observation

@Observable
@MainActor
final class ExerciseViewModel {
    var healthKitWorkouts: [WorkoutSummary] = [] { didSet { invalidateCache() } }
    var manualRecords: [ExerciseRecord] = [] { didSet { invalidateCache() } }
    var isLoading = false
    var errorMessage: String?

    private let workoutService: WorkoutQuerying
    private let exerciseLibrary: ExerciseLibraryQuerying

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
    private func invalidateCache() {
        let externalWorkouts = healthKitWorkouts.filteringAppDuplicates(against: manualRecords)

        var items: [ExerciseListItem] = []
        items.reserveCapacity(externalWorkouts.count + manualRecords.count)

        for workout in externalWorkouts {
            items.append(ExerciseListItem(
                id: workout.id,
                type: workout.type,
                duration: workout.duration,
                calories: workout.calories,
                distance: workout.distance,
                date: workout.date,
                source: .healthKit
            ))
        }

        for record in manualRecords {
            let localizedName: String? = record.exerciseDefinitionID.flatMap {
                exerciseLibrary.exercise(byID: $0)?.localizedName
            }
            let hasHKLink = record.healthKitWorkoutID.map { !$0.isEmpty } ?? false
            items.append(ExerciseListItem(
                id: record.id.uuidString,
                type: record.exerciseType,
                localizedType: localizedName,
                duration: record.duration,
                calories: record.bestCalories,
                distance: record.distance,
                date: record.date,
                source: .manual,
                completedSets: record.completedSets,
                exerciseDefinitionID: record.exerciseDefinitionID,
                isLinkedToHealthKit: hasHKLink
            ))
        }

        allExercises = items.sorted { $0.date > $1.date }
    }

    func loadHealthKitWorkouts() async {
        isLoading = true
        do {
            healthKitWorkouts = try await workoutService.fetchWorkouts(days: 30)
        } catch {
            AppLogger.ui.error("Exercise data load failed: \(error.localizedDescription)")
            errorMessage = "Could not load workout data"
        }
        isLoading = false
    }

}

struct ExerciseListItem: Identifiable {
    let id: String
    let type: String
    let localizedType: String?
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let date: Date
    let source: Source
    let completedSets: [WorkoutSet]
    let exerciseDefinitionID: String?
    let isLinkedToHealthKit: Bool

    init(
        id: String, type: String, localizedType: String? = nil,
        duration: TimeInterval,
        calories: Double?, distance: Double?, date: Date,
        source: Source, completedSets: [WorkoutSet] = [],
        exerciseDefinitionID: String? = nil,
        isLinkedToHealthKit: Bool = false
    ) {
        self.id = id
        self.type = type
        self.localizedType = localizedType
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.date = date
        self.source = source
        self.completedSets = completedSets
        self.exerciseDefinitionID = exerciseDefinitionID
        self.isLinkedToHealthKit = isLinkedToHealthKit
    }

    enum Source {
        case healthKit
        case manual
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
