import SwiftUI

struct TrainingReadinessHeroCard: View {
    let readiness: TrainingReadiness?
    let isCalibrating: Bool

    private enum Labels {
        static let scoreLabel = String(localized: "READINESS")
        static let hrv = String(localized: "HRV")
        static let sleep = String(localized: "Sleep")
        static let recovery = String(localized: "Recovery")
        static let calibrating = String(localized: "Calibrating")
    }

    var body: some View {
        if let readiness {
            HeroScoreCard(
                score: readiness.score,
                scoreLabel: Labels.scoreLabel,
                statusLabel: readiness.status.label,
                statusIcon: readiness.status.iconName,
                statusColor: readiness.status.color,
                guideMessage: readiness.narrativeMessage,
                subScores: [
                    .init(label: Labels.hrv, value: readiness.components.hrvScore, color: DS.Color.hrv),
                    .init(label: Labels.sleep, value: readiness.components.sleepScore, color: DS.Color.sleep),
                    .init(label: Labels.recovery, value: readiness.components.fatigueScore, color: DS.Color.activity)
                ],
                badgeText: isCalibrating ? Labels.calibrating : nil,
                showsChevron: false,
                accessibilityLabel: String(localized: "Training readiness \(readiness.score), \(readiness.status.label)"),
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
                    .foregroundStyle(DS.Color.textSecondary)

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
