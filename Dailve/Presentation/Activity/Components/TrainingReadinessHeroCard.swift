import SwiftUI

struct TrainingReadinessHeroCard: View {
    let readiness: TrainingReadiness?
    let isCalibrating: Bool

    var body: some View {
        if let readiness {
            HeroScoreCard(
                score: readiness.score,
                scoreLabel: "READINESS",
                statusLabel: readiness.status.label,
                statusIcon: readiness.status.iconName,
                statusColor: readiness.status.color,
                guideMessage: readiness.status.guideMessage,
                subScores: [
                    .init(label: "HRV", value: readiness.components.hrvScore, color: DS.Color.hrv),
                    .init(label: "Sleep", value: readiness.components.sleepScore, color: DS.Color.sleep),
                    .init(label: "Recovery", value: readiness.components.fatigueScore, color: DS.Color.activity)
                ],
                badgeText: isCalibrating ? "Calibrating" : nil,
                showsChevron: false,
                accessibilityLabel: "Training readiness \(readiness.score), \(readiness.status.label)",
                accessibilityHint: nil
            )
        } else {
            emptyCard
        }
    }

    // MARK: - Empty State

    private var emptyCard: some View {
        HeroCard(tintColor: DS.Color.activity.opacity(0.5)) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "figure.run")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)

                Text("Need More Data")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Track your workouts and wear Apple Watch to see your training readiness score.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
        }
    }
}
