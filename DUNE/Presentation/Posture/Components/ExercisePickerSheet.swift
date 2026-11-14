#if !os(visionOS)
import SwiftUI

/// Bottom sheet for selecting an exercise for form checking.
struct ExercisePickerSheet: View {
    let exercises: [ExerciseFormRule]
    let selectedExerciseID: String?
    let onSelect: (ExerciseFormRule?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var symbolSize: CGFloat = 22

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        Group {
            if dynamicTypeSize == .accessibility5 {
                // Keep dismissal as a fixed sibling above the scrolling list at MAX.
                VStack(spacing: 0) {
                    maximumSizeHeader
                    exerciseList
                }
            } else {
                NavigationStack {
                    exerciseList
                        .navigationTitle("Exercise Mode")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                closeButton
                            }
                        }
                }
            }
        }
        .presentationDetents(dynamicTypeSize == .accessibility5 ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var maximumSizeHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            closeButton
                .foregroundStyle(.primary)
                .font(.body)
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            Text(verbatim: "Exercise Mode")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(.regularMaterial)
    }

    private var closeButton: some View {
        Button("Close") { dismiss() }
            .accessibilityIdentifier("posture-exercise-close")
    }

    private var exerciseList: some View {
        List {
            // General posture mode (no exercise)
            Button {
                onSelect(nil)
                dismiss()
            } label: {
                exerciseLabel("General Posture", icon: "figure.stand", selected: selectedExerciseID == nil)
            }
            .tint(.primary)
            .listRowBackground(palette.surface)
            .foregroundStyle(palette.ink)
            .accessibilityIdentifier("posture-exercise-general")
            .accessibilityAddTraits(selectedExerciseID == nil ? .isSelected : [])

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
                    .accessibilityIdentifier("posture-exercise-\(exercise.exerciseID)")
                    .accessibilityAddTraits(selectedExerciseID == exercise.exerciseID ? .isSelected : [])
                }
            }
        }
        .accessibilityIdentifier("posture-exercise-list")
        .scrollContentBackground(.hidden)
        .background { SheetWaveBackground().opacity(0.45) }
    }

    private func exerciseLabel(_ title: LocalizedStringKey, icon: String, selected: Bool) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        return layout {
            Image(systemName: icon)
                .font(.system(size: min(symbolSize, 36)))
                .frame(width: min(symbolSize, 36) + DS.Spacing.lg, height: min(symbolSize, 36) + DS.Spacing.lg)
                .background(DS.Color.body.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(DS.Color.warmGlow)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
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
