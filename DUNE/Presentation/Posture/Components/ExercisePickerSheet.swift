#if !os(visionOS)
import SwiftUI

/// Bottom sheet for selecting an exercise for form checking.
struct ExercisePickerSheet: View {
    let exercises: [ExerciseFormRule]
    let selectedExerciseID: String?
    let onSelect: (ExerciseFormRule?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                // General posture mode (no exercise)
                Button {
                    onSelect(nil)
                    dismiss()
                } label: {
                    exerciseLabel("General Posture", icon: "figure.stand", selected: selectedExerciseID == nil)
                }
                .tint(.primary)

                Section("Form Check") {
                    ForEach(exercises) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            exerciseLabel(
                                LocalizedStringKey(exercise.displayName),
                                icon: iconName(for: exercise),
                                selected: selectedExerciseID == exercise.exerciseID
                            )
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Exercise Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func exerciseLabel(_ title: LocalizedStringKey, icon: String, selected: Bool) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        return layout {
            Image(systemName: icon)
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(DS.Color.warmGlow)
            }
        }
    }

    private func iconName(for exercise: ExerciseFormRule) -> String {
        switch exercise.exerciseID {
        case "barbell-squat": return "figure.strengthtraining.traditional"
        case "conventional-deadlift": return "figure.strengthtraining.functional"
        case "overhead-press": return "figure.arms.open"
        case "pull-up": return "figure.highintensity.intervaltraining"
        case "bodyweight-squat": return "figure.flexibility"
        case "lunge": return "figure.step.training"
        default: return "figure.mixed.cardio"
        }
    }
}
#endif
