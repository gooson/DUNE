import SwiftUI

/// Displays tonight's sleep quality prediction with outlook, score, and improvement tips.
struct SleepPredictionCard: View {
    let prediction: SleepQualityPrediction?

    @Environment(\.appTheme) private var theme

    private static let gaugeTrackColor = DS.Color.sleep.opacity(0.15)

    var body: some View {
        if let prediction {
            filledContent(prediction)
        } else {
            emptyState
        }
    }

    private func filledContent(_ prediction: SleepQualityPrediction) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Score + Outlook
                HStack(spacing: DS.Spacing.md) {
                    // Moon gauge
                    ZStack {
                        Circle()
                            .stroke(Self.gaugeTrackColor, lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: CGFloat(prediction.predictedScore) / 100.0)
                            .stroke(
                                outlookColor(prediction.outlook),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Text("\(prediction.predictedScore)")
                            .font(DS.Typography.cardScore)
                            .foregroundStyle(theme.heroTextGradient)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(prediction.outlook.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(outlookColor(prediction.outlook))
                        Text(prediction.outlook.guideMessage)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    // Confidence badge
                    Text(prediction.confidence.displayName)
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                // Factors (max 3)
                let topFactors = Array(prediction.factors.prefix(3))
                if !topFactors.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(topFactors, id: \.type) { factor in
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: impactIcon(factor.impact))
                                    .font(.caption2)
                                    .foregroundStyle(impactColor(factor.impact))
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

                // Tips (max 2)
                let topTips = Array(prediction.tips.prefix(2))
                if !topTips.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        ForEach(Array(topTips.enumerated()), id: \.offset) { _, tip in
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "lightbulb")
                                    .font(.caption2)
                                    .foregroundStyle(DS.Color.caution)
                                    .frame(width: 16)
                                Text(tip)
                                    .font(.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .lineLimit(2)
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
                Image(systemName: "moon.zzz")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("Sleep a few nights to see your sleep quality prediction.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    // MARK: - Helpers

    private func outlookColor(_ outlook: SleepQualityPrediction.Outlook) -> Color {
        switch outlook {
        case .poor: DS.Color.negative
        case .fair: DS.Color.caution
        case .good: DS.Color.positive
        case .excellent: DS.Color.sleep
        }
    }

    private func impactIcon(_ impact: SleepQualityPrediction.Impact) -> String {
        switch impact {
        case .positive: "arrow.up.circle.fill"
        case .neutral: "minus.circle.fill"
        case .negative: "arrow.down.circle.fill"
        }
    }

    private func impactColor(_ impact: SleepQualityPrediction.Impact) -> Color {
        switch impact {
        case .positive: DS.Color.positive
        case .neutral: DS.Color.textSecondary
        case .negative: DS.Color.negative
        }
    }
}
