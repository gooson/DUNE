import SwiftUI

/// Dedicated card for workout recommendations on the Today tab.
/// Shows suggested exercises with muscle targets and intensity indicator.
struct WorkoutRecommendationCard: View {
    let suggestion: WorkoutSuggestion
    let onStartWorkout: (() -> Void)?

    // Pre-computed colors to avoid per-ForEach allocation (Correction #105)
    private static let tagBackground = DS.Color.activity.opacity(DS.Opacity.subtle)
    private static let bulletColor = DS.Color.activity.opacity(DS.Opacity.medium)

    init(suggestion: WorkoutSuggestion, onStartWorkout: (() -> Void)? = nil) {
        self.suggestion = suggestion
        self.onStartWorkout = onStartWorkout
    }

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundStyle(DS.Color.activity)
                    Text("오늘의 추천 운동")
                        .font(.subheadline.weight(.semibold))
                }

                // Muscle tags
                if !suggestion.focusMuscles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.xs) {
                            ForEach(suggestion.focusMuscles.prefix(4), id: \.self) { muscle in
                                Text(muscle.localizedDisplayName)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, DS.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background {
                                        Capsule()
                                            .fill(Self.tagBackground)
                                    }
                            }
                        }
                    }
                }

                // Exercise list
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    ForEach(suggestion.exercises.prefix(3)) { exercise in
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(Self.bulletColor)
                                .frame(width: 5, height: 5)
                            Text(exercise.definition.localizedName)
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                            Spacer()
                            if exercise.suggestedSets > 0 {
                                Text("\(exercise.suggestedSets) sets")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                // Reasoning + CTA
                HStack {
                    Text(suggestion.reasoning)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Spacer()

                    if let onStartWorkout {
                        Button(action: onStartWorkout) {
                            Text("운동 시작")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(DS.Color.activity)
                    }
                }
            }
        }
    }
}
