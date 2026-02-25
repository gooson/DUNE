import Foundation
import SwiftData

@Model
final class ExerciseRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var exerciseType: String = ""
    var duration: TimeInterval = 0
    var calories: Double?
    var distance: Double?
    var memo: String = ""
    var isFromHealthKit: Bool = false
    var healthKitWorkoutID: String?
    var createdAt: Date = Date()

    // V2 fields
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exerciseRecord)
    var sets: [WorkoutSet]? = []
    var exerciseDefinitionID: String?
    var primaryMusclesRaw: [String] = []
    var secondaryMusclesRaw: [String] = []
    var equipmentRaw: String?
    var estimatedCalories: Double?
    var calorieSourceRaw: String = CalorieSource.manual.rawValue
    /// User-rated perceived exertion (1-10). nil means user skipped.
    var rpe: Int?

    init(
        date: Date = Date(),
        exerciseType: String = "",
        duration: TimeInterval = 0,
        calories: Double? = nil,
        distance: Double? = nil,
        memo: String = "",
        isFromHealthKit: Bool = false,
        healthKitWorkoutID: String? = nil,
        exerciseDefinitionID: String? = nil,
        primaryMuscles: [MuscleGroup] = [],
        secondaryMuscles: [MuscleGroup] = [],
        equipment: Equipment? = nil,
        estimatedCalories: Double? = nil,
        calorieSource: CalorieSource = .manual,
        rpe: Int? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.exerciseType = exerciseType
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.memo = memo
        self.isFromHealthKit = isFromHealthKit
        self.healthKitWorkoutID = healthKitWorkoutID
        self.createdAt = Date()
        self.exerciseDefinitionID = exerciseDefinitionID
        self.primaryMusclesRaw = primaryMuscles.map(\.rawValue)
        self.secondaryMusclesRaw = secondaryMuscles.map(\.rawValue)
        self.equipmentRaw = equipment?.rawValue
        self.estimatedCalories = estimatedCalories
        self.calorieSourceRaw = calorieSource.rawValue
        self.rpe = rpe
    }

    // MARK: - Computed Accessors

    var primaryMuscles: [MuscleGroup] {
        primaryMusclesRaw.compactMap { MuscleGroup(rawValue: $0) }
    }

    var secondaryMuscles: [MuscleGroup] {
        secondaryMusclesRaw.compactMap { MuscleGroup(rawValue: $0) }
    }

    var equipment: Equipment? {
        equipmentRaw.flatMap { Equipment(rawValue: $0) }
    }

    var calorieSource: CalorieSource {
        CalorieSource(rawValue: calorieSourceRaw) ?? .manual
    }

    /// Best available calorie value: HealthKit > MET estimation > manual input
    var bestCalories: Double? {
        switch calorieSource {
        case .healthKit: calories
        case .met: estimatedCalories
        case .manual: calories
        }
    }

    /// Whether this record has structured set data (vs legacy flat record)
    var hasSetData: Bool {
        !(sets ?? []).isEmpty
    }

    /// Completed sets sorted by setNumber
    var completedSets: [WorkoutSet] {
        (sets ?? []).filter(\.isCompleted).sorted { $0.setNumber < $1.setNumber }
    }
}
