import Foundation
import Observation

@Observable
@MainActor
final class ExerciseViewModel {
    static let exerciseTypes = [
        "Running", "Walking", "Cycling", "Swimming",
        "Strength", "HIIT", "Yoga", "Hiking", "Other"
    ]

    private let maxCalories = 10_000.0
    private let maxDistanceMeters = 500_000.0
    private let maxMemoLength = 500
    private let defaultDuration: TimeInterval = 30 * 60

    var healthKitWorkouts: [WorkoutSummary] = [] { didSet { invalidateCache() } }
    var manualRecords: [ExerciseRecord] = [] { didSet { invalidateCache() } }
    var isLoading = false
    var isShowingAddSheet = false
    var errorMessage: String?

    // Add form fields
    var newExerciseType = ""
    var newDuration: TimeInterval = 30 * 60 // overwritten by defaultDuration in resetForm
    var newCalories: String = ""
    var newDistance: String = ""
    var newMemo = ""
    var selectedDate: Date = Date() { didSet { validationError = nil } }

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
                calories: record.calories,
                distance: record.distance,
                date: record.date,
                source: .manual
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

    var isSaving = false
    var validationError: String?

    func createValidatedRecord() -> ExerciseRecord? {
        guard !isSaving else { return nil }
        guard !newExerciseType.isEmpty else { return nil }

        validationError = nil

        if selectedDate.isFuture {
            validationError = "Future dates are not allowed"
            return nil
        }

        if !newCalories.isEmpty {
            guard let cal = Double(newCalories), cal >= 0, cal <= maxCalories else {
                validationError = "Calories must be between 0 and \(Int(maxCalories).formatted()) kcal"
                return nil
            }
        }
        if !newDistance.isEmpty {
            guard let dist = Double(newDistance), dist >= 0, dist <= maxDistanceMeters else {
                validationError = "Distance must be between 0 and \(Int(maxDistanceMeters / 1000)) km"
                return nil
            }
        }

        isSaving = true
        defer { isSaving = false }

        return ExerciseRecord(
            date: selectedDate,
            exerciseType: newExerciseType,
            duration: newDuration,
            calories: Double(newCalories),
            distance: Double(newDistance),
            memo: String(newMemo.prefix(maxMemoLength))
        )
    }

    func resetForm() {
        newExerciseType = ""
        newDuration = defaultDuration
        newCalories = ""
        newDistance = ""
        newMemo = ""
        selectedDate = Date()
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

    enum Source {
        case healthKit
        case manual
    }

    var formattedDuration: String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}
