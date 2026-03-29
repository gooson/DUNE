import SwiftUI

struct ExerciseIntelligenceCard: View {
    let suggestion: WorkoutSuggestion
    let conditionScore: Int?
    let sleepMinutes: Double?
    let onStartWorkout: () -> Void

    private enum Labels {
        static let readyModerate = String(localized: "ready for moderate+ intensity")
        static let lightEffort = String(localized: "light effort recommended")
        static let recoverySufficient = String(localized: "recovery sufficient")
        static let recoveryLimited = String(localized: "recovery limited")
    }

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundStyle(DS.Color.activity)
                        .font(.subheadline)

                    Text("Today's Recommendation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.textSecondary)

                    Spacer()
                }

                // Workout summary
                if !suggestion.exercises.isEmpty {
                    let focusText = suggestion.focusMuscles.prefix(3)
                        .map(\.displayName)
                        .joined(separator: " · ")

                    Text(focusText)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Divider().opacity(0.3)

                // Reasoning bullets
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Why this workout")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)

                    Text(suggestion.reasoning)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .lineLimit(3)

                    if let score = conditionScore {
                        let intensityLabel = score >= 70 ? Labels.readyModerate : Labels.lightEffort
                        reasoningBullet(
                            icon: "heart.fill",
                            text: String(localized: "Condition \(score) — \(intensityLabel)")
                        )
                    }

                    if let minutes = sleepMinutes, minutes > 0 {
                        let hours = Int(minutes) / 60
                        let mins = Int(minutes) % 60
                        let sleepText = mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
                        let recoveryLabel = minutes >= 420 ? Labels.recoverySufficient : Labels.recoveryLimited
                        reasoningBullet(
                            icon: "bed.double.fill",
                            text: String(localized: "\(sleepText) sleep — \(recoveryLabel)")
                        )
                    }
                }

                // CTA
                Button(action: onStartWorkout) {
                    Text("Start this workout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Color.activity.opacity(0.15), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .foregroundStyle(DS.Color.activity)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dashboard-intelligence-start")
            }
        }
        .accessibilityIdentifier("dashboard-exercise-intelligence")
    }

    private func reasoningBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }
}
