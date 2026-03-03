import SwiftUI

/// Shared column headers for exercise set lists.
/// Used by CompoundWorkoutView and TemplateWorkoutView.
struct ExerciseSetColumnHeaders: View {
    let exercise: ExerciseDefinition
    let weightUnit: WeightUnit

    var body: some View {
        switch exercise.inputType {
        case .setsRepsWeight:
            HStack(spacing: DS.Spacing.xs) {
                Text(weightUnit.displayName.uppercased()).frame(maxWidth: 70)
                Text("REPS").frame(maxWidth: 60)
            }
        case .setsReps:
            HStack(spacing: DS.Spacing.xs) {
                Text("REPS").frame(maxWidth: 70)
            }
        case .durationDistance:
            let unit = exercise.cardioSecondaryUnit ?? .km
            HStack(spacing: DS.Spacing.xs) {
                Text("MIN").frame(maxWidth: 60)
                if unit != .timeOnly {
                    Text(unit.placeholder.uppercased()).frame(maxWidth: 70)
                }
            }
        case .durationIntensity:
            Text("MIN").frame(maxWidth: 60)
        case .roundsBased:
            HStack(spacing: DS.Spacing.xs) {
                Text("REPS").frame(maxWidth: 60)
                Text("SEC").frame(maxWidth: 60)
            }
        }
    }
}
