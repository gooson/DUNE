import Foundation

struct ExerciseDefinition: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let localizedName: String
    let category: ExerciseCategory
    let inputType: ExerciseInputType
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let equipment: Equipment
    let metValue: Double
    let description: String?

    init(
        id: String,
        name: String,
        localizedName: String,
        category: ExerciseCategory,
        inputType: ExerciseInputType,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup],
        equipment: Equipment,
        metValue: Double,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.localizedName = localizedName
        self.category = category
        self.inputType = inputType
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.metValue = metValue
        self.description = description
    }
}
