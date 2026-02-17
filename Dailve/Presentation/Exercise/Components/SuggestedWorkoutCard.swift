import SwiftUI

struct SuggestedWorkoutCard: View {
    let suggestion: WorkoutSuggestion
    let onStartExercise: (ExerciseDefinition) -> Void

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
                    onStartExercise(exercise.definition)
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(exercise.definition.localizedName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(exercise.suggestedSets) sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, DS.Spacing.xxs)
                }
                .buttonStyle(.plain)
            }

            // Reasoning
            if suggestion.exercises.isEmpty {
                Text(suggestion.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.md)
    }
}
