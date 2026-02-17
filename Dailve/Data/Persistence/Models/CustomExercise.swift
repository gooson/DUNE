import Foundation
import SwiftData

@Model
final class CustomExercise {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = ExerciseCategory.strength.rawValue
    var inputTypeRaw: String = ExerciseInputType.setsRepsWeight.rawValue
    var primaryMusclesRaw: [String] = []
    var secondaryMusclesRaw: [String] = []
    var equipmentRaw: String = Equipment.bodyweight.rawValue
    var metValue: Double = 3.5
    var customCategoryName: String?
    var createdAt: Date = Date()

    /// Valid MET value range (physiological limits: 0.9 resting to ~30 sprint)
    static let metValueRange: ClosedRange<Double> = 0.9...30.0

    init(
        name: String,
        category: ExerciseCategory,
        inputType: ExerciseInputType,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup] = [],
        equipment: Equipment,
        metValue: Double = 3.5,
        customCategoryName: String? = nil
    ) {
        self.id = UUID()
        self.name = String(name.prefix(100))
        self.categoryRaw = category.rawValue
        self.inputTypeRaw = inputType.rawValue
        self.primaryMusclesRaw = primaryMuscles.map(\.rawValue)
        self.secondaryMusclesRaw = secondaryMuscles.map(\.rawValue)
        self.equipmentRaw = equipment.rawValue
        self.metValue = min(max(metValue, Self.metValueRange.lowerBound), Self.metValueRange.upperBound)
        self.customCategoryName = customCategoryName.map { String($0.prefix(50)) }
        self.createdAt = Date()
    }

    // MARK: - Typed Accessors

    var category: ExerciseCategory {
        ExerciseCategory(rawValue: categoryRaw) ?? .strength
    }

    var inputType: ExerciseInputType {
        ExerciseInputType(rawValue: inputTypeRaw) ?? .setsRepsWeight
    }

    var primaryMuscles: [MuscleGroup] {
        primaryMusclesRaw.compactMap { MuscleGroup(rawValue: $0) }
    }

    var secondaryMuscles: [MuscleGroup] {
        secondaryMusclesRaw.compactMap { MuscleGroup(rawValue: $0) }
    }

    var equipment: Equipment {
        Equipment(rawValue: equipmentRaw) ?? .bodyweight
    }

    /// Convert to ExerciseDefinition for use in workout sessions
    func toDefinition() -> ExerciseDefinition {
        ExerciseDefinition(
            id: "custom-\(id.uuidString)",
            name: name,
            localizedName: name,
            category: category,
            inputType: inputType,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            metValue: metValue,
            customCategoryName: customCategoryName
        )
    }
}
