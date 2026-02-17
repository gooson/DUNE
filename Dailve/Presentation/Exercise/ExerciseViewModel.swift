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

    init(workoutService: WorkoutQuerying? = nil) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: .shared)
    }

    private(set) var allExercises: [ExerciseListItem] = []

    private func invalidateCache() {
        var items: [ExerciseListItem] = []
        items.reserveCapacity(healthKitWorkouts.count + manualRecords.count)

        for workout in healthKitWorkouts {
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
            items.append(ExerciseListItem(
                id: record.id.uuidString,
                type: record.exerciseType,
                duration: record.duration,
                calories: record.bestCalories,
                distance: record.distance,
                date: record.date,
                source: .manual,
                completedSets: record.completedSets,
                exerciseDefinitionID: record.exerciseDefinitionID
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

}

struct ExerciseListItem: Identifiable {
    let id: String
    let type: String
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let date: Date
    let source: Source
    let completedSets: [WorkoutSet]
    let exerciseDefinitionID: String?

    init(
        id: String, type: String, duration: TimeInterval,
        calories: Double?, distance: Double?, date: Date,
        source: Source, completedSets: [WorkoutSet] = [],
        exerciseDefinitionID: String? = nil
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.date = date
        self.source = source
        self.completedSets = completedSets
        self.exerciseDefinitionID = exerciseDefinitionID
    }

    enum Source {
        case healthKit
        case manual
    }

    var formattedDuration: String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }

    var setSummary: String? {
        completedSets.setSummary()
    }
}
