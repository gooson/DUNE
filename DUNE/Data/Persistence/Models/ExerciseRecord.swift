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
    var stepCount: Int?
    /// Average pace for cardio sessions (seconds per kilometer).
    var averagePaceSecondsPerKm: Double?
    /// Average cadence for cardio sessions (steps per minute).
    var averageCadenceStepsPerMinute: Double?
    /// Elevation gain for cardio sessions (meters).
    var elevationGainMeters: Double?
    /// Floors ascended reported by motion sensors.
    var floorsAscended: Double?
    /// Average machine level for non-distance machine cardio sessions.
    var cardioMachineLevelAverage: Double?
    /// Max machine level reached during non-distance machine cardio sessions.
    var cardioMachineLevelMax: Int?
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
    /// Auto-calculated workout intensity (0.0–1.0). nil means not computed.
    var autoIntensityRaw: Double?
    /// VO2 Max (cardio fitness) captured at workout time (ml/kg/min). nil if unavailable.
    var cardioFitnessVO2Max: Double?

    init(
        date: Date = Date(),
        exerciseType: String = "",
        duration: TimeInterval = 0,
        calories: Double? = nil,
        distance: Double? = nil,
        stepCount: Int? = nil,
        averagePaceSecondsPerKm: Double? = nil,
        averageCadenceStepsPerMinute: Double? = nil,
        elevationGainMeters: Double? = nil,
        floorsAscended: Double? = nil,
        cardioMachineLevelAverage: Double? = nil,
        cardioMachineLevelMax: Int? = nil,
        memo: String = "",
        isFromHealthKit: Bool = false,
        healthKitWorkoutID: String? = nil,
        exerciseDefinitionID: String? = nil,
        primaryMuscles: [MuscleGroup] = [],
        secondaryMuscles: [MuscleGroup] = [],
        equipment: Equipment? = nil,
        estimatedCalories: Double? = nil,
        calorieSource: CalorieSource = .manual,
        rpe: Int? = nil,
        autoIntensityRaw: Double? = nil,
        cardioFitnessVO2Max: Double? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.exerciseType = exerciseType
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.stepCount = stepCount
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.averageCadenceStepsPerMinute = averageCadenceStepsPerMinute
        self.elevationGainMeters = elevationGainMeters
        self.floorsAscended = floorsAscended
        self.cardioMachineLevelAverage = cardioMachineLevelAverage
        self.cardioMachineLevelMax = cardioMachineLevelMax.flatMap { (1...99).contains($0) ? $0 : nil }
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
        self.autoIntensityRaw = autoIntensityRaw
        self.cardioFitnessVO2Max = cardioFitnessVO2Max
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

    /// Whether this record carries user-visible content beyond a bare stub.
    /// Empty stubs (0 duration, no calories, no sets) linked to HealthKit
    /// should defer to the richer HealthKit WorkoutSummary.
    var hasMeaningfulContent: Bool {
        hasSetData || duration > 0 || bestCalories != nil
    }

    /// Completed sets sorted by setNumber
    var completedSets: [WorkoutSet] {
        (sets ?? []).filter(\.isCompleted).sorted { $0.setNumber < $1.setNumber }
    }
}
