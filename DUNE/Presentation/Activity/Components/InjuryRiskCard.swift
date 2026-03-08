import SwiftUI

/// Displays injury risk score with level indicator and top risk factors.
struct InjuryRiskCard: View {
    let assessment: InjuryRiskAssessment?

    @Environment(\.appTheme) private var theme

    private static let gaugeTrackColor = DS.Color.activity.opacity(0.15)

    var body: some View {
        if let assessment {
            filledContent(assessment)
        } else {
            emptyState
        }
    }

    private func filledContent(_ assessment: InjuryRiskAssessment) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Score + Level
                HStack(spacing: DS.Spacing.md) {
                    // Circular gauge
                    ZStack {
                        Circle()
                            .stroke(Self.gaugeTrackColor, lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: CGFloat(assessment.score) / 100.0)
                            .stroke(
                                levelColor(assessment.level),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Text("\(assessment.score)")
                            .font(DS.Typography.cardScore)
                            .foregroundStyle(theme.heroTextGradient)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(assessment.level.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(levelColor(assessment.level))
                        Text(assessment.level.guideMessage)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Top risk factors (max 3, pre-sorted by UseCase)
                let topFactors = Array(assessment.factors.prefix(3))

                if !topFactors.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(topFactors, id: \.type) { factor in
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: factorIcon(factor.type))
                                    .font(.caption2)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .frame(width: 16)
                                Text(factor.detail)
                                    .font(.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "shield.checkered")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("Train for a few days to see your injury risk assessment.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    // MARK: - Helpers

    private func levelColor(_ level: InjuryRiskAssessment.Level) -> Color {
        switch level {
        case .low: DS.Color.positive
        case .moderate: DS.Color.caution
        case .high: .orange
        case .critical: DS.Color.negative
        }
    }

    private func factorIcon(_ type: InjuryRiskAssessment.FactorType) -> String {
        switch type {
        case .muscleFatigue: "figure.walk"
        case .consecutiveTraining: "calendar.badge.exclamationmark"
        case .volumeSpike: "chart.line.uptrend.xyaxis"
        case .sleepDeficit: "moon.zzz"
        case .activeInjury: "bandage"
        case .lowRecovery: "battery.25percent"
        }
    }
}
