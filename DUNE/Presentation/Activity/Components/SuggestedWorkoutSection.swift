import SwiftUI

/// Standalone suggested workout section, extracted from MuscleRecoveryMapView.
struct SuggestedWorkoutSection: View {
    let suggestion: WorkoutSuggestion?
    let onStartExercise: (ExerciseDefinition) -> Void

    var body: some View {
        if let suggestion {
            if suggestion.isRestDay {
                restDayContent(suggestion: suggestion)
            } else {
                workoutContent(suggestion: suggestion)
            }
        }
    }

    // MARK: - Workout

    private func workoutContent(suggestion: WorkoutSuggestion) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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

                ForEach(suggestion.exercises) { exercise in
                    SuggestedExerciseRow(
                        exercise: exercise,
                        onStart: { onStartExercise(exercise.definition) },
                        onAlternativeSelected: { alt in onStartExercise(alt) }
                    )
                }
            }
        }
    }

    // MARK: - Rest Day

    private func restDayContent(suggestion: WorkoutSuggestion) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bed.double.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Recovery Day")
                        .font(.subheadline.weight(.semibold))
                }

                Text(suggestion.reasoning)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                if let next = suggestion.nextReadyMuscle {
                    nextReadyLabel(muscle: next.muscle, date: next.readyDate)
                }

                if !suggestion.activeRecoverySuggestions.isEmpty {
                    ActiveRecoveryCard(suggestions: suggestion.activeRecoverySuggestions)
                }
            }
        }
    }

    private func nextReadyLabel(muscle: MuscleGroup, date: Date) -> some View {
        let hours = Swift.max(0, date.timeIntervalSince(Date()) / 3600)
        let timeText: String
        if hours < 1 {
            timeText = String(localized: "soon")
        } else if hours < 24 {
            timeText = String(localized: "in ~\(Int(hours).formattedWithSeparator)h")
        } else {
            let days = Int(hours / 24)
            timeText = String(localized: "in ~\(days.formattedWithSeparator)d")
        }

        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
            Text(String(localized: "\(muscle.displayName) ready \(timeText)"))
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }
}
