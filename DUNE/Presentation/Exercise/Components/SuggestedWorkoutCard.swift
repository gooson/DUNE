import SwiftUI

struct SuggestedWorkoutCard: View {
    let suggestion: WorkoutSuggestion
    let onStartExercise: (ExerciseDefinition) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedExercise: ExerciseDefinition?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.activity)
                Text("Suggested Workout")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            // Focus muscles
            if !suggestion.focusMuscles.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(suggestion.focusMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(DS.Color.activity.opacity(0.12), in: Capsule())
                            .foregroundStyle(DS.Color.activity)
                    }
                }
            }

            // Exercises
            ForEach(suggestion.exercises) { exercise in
                Button {
                    selectedExercise = exercise.definition
                } label: {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
                        : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
                    layout {
                        Text(exercise.definition.localizedName)
                            .font(.subheadline)
                            .foregroundStyle(theme.sandColor)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .fixedSize(horizontal: false, vertical: true)

                        if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                        HStack {
                            Text("\(exercise.suggestedSets.formattedWithSeparator) sets")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xxs)
                }
                .buttonStyle(.plain)
            }

            // Reasoning
            if suggestion.exercises.isEmpty {
                Text(suggestion.reasoning)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .padding(DS.Spacing.md)
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailSheet(exercise: exercise) {
                onStartExercise(exercise)
            }
        }
    }
}
