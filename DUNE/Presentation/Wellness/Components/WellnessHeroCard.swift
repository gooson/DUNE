import SwiftUI

struct WellnessHeroCard: View {
    let score: WellnessScore?
    let sleepScore: Int?
    let conditionScore: Int?
    let bodyScore: Int?

    private enum Labels {
        static let wellness = String(localized: "WELLNESS")
        static let sleep = String(localized: "Sleep")
        static let condition = String(localized: "Condition")
        static let body = String(localized: "Body")
    }

    var body: some View {
        if let score {
            HeroScoreCard(
                score: score.score,
                scoreLabel: Labels.wellness,
                statusLabel: score.status.label,
                statusIcon: score.status.iconName,
                statusColor: score.status.color,
                guideMessage: score.narrativeMessage,
                subScores: [
                    .init(label: Labels.sleep, value: sleepScore, color: DS.Color.sleep),
                    .init(label: Labels.condition, value: conditionScore, color: DS.Color.hrv),
                    .init(label: Labels.body, value: bodyScore, color: DS.Color.body)
                ],
                badgeText: nil,
                showsChevron: true,
                accessibilityLabel: "Wellness score \(score.score), \(score.status.label)",
                accessibilityHint: "Tap to see score details"
            )
        } else {
            emptyCard
        }
    }

    // MARK: - Empty State

    private var emptyCard: some View {
        HeroCard(tintColor: DS.Color.fitness.opacity(0.5)) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)

                Text("Need More Data")
                    .font(.headline)
                    .foregroundStyle(DS.Color.textSecondary)

                Text("Wear your Apple Watch tonight to start tracking your wellness score.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
        }
    }
}
