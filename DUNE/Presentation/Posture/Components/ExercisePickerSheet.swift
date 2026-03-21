#if !os(visionOS)
import SwiftUI

/// Bottom sheet for selecting an exercise for form checking.
struct ExercisePickerSheet: View {
    let exercises: [ExerciseFormRule]
    let selectedExerciseID: String?
    let onSelect: (ExerciseFormRule?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // General posture mode (no exercise)
                Button {
                    onSelect(nil)
                    dismiss()
                } label: {
                    HStack {
                        Label(String(localized: "General Posture"), systemImage: "figure.stand")
                        Spacer()
                        if selectedExerciseID == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DS.Color.warmGlow)
                        }
                    }
                }
                .tint(.primary)

                Section(String(localized: "Form Check")) {
                    ForEach(exercises) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            HStack {
                                Label(exercise.displayName, systemImage: iconName(for: exercise))
                                Spacer()
                                if selectedExerciseID == exercise.exerciseID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(DS.Color.warmGlow)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Exercise Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func iconName(for exercise: ExerciseFormRule) -> String {
        switch exercise.exerciseID {
        case "barbell-squat": return "figure.strengthtraining.traditional"
        case "conventional-deadlift": return "figure.strengthtraining.functional"
        case "overhead-press": return "figure.arms.open"
        default: return "figure.mixed.cardio"
        }
    }
}
#endif
