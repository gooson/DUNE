import SwiftUI

/// Full detail view for Tonight's Sleep Quality Prediction — all factors, tips, confidence.
struct SleepPredictionDetailView: View {
    let prediction: SleepQualityPrediction

    private enum Labels {
        static let factors = String(localized: "All Factors")
        static let tips = String(localized: "Sleep Tips")
        static let noFactors = String(localized: "No prediction factors available")
        static let noTips = String(localized: "No sleep tips at this time")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                scoreHero
                confidenceBadge
                factorsSection
                tipsSection
            }
            .padding()
        }
        .background {
            DetailWaveBackground()
                .environment(\.waveColor, DS.Color.sleep)
        }
        .englishNavigationTitle("Tonight's Sleep")
        .accessibilityIdentifier("wellness-sleep-prediction-detail-screen")
    }

    // MARK: - Score Hero

    private var scoreHero: some View {
        DetailScoreHero(
            score: prediction.predictedScore,
            scoreLabel: "SLEEP",
            statusLabel: prediction.outlook.displayName,
            statusIcon: prediction.outlook.iconName,
            statusColor: prediction.outlook.color,
            guideMessage: prediction.outlook.guideMessage
        )
    }

    // MARK: - Confidence Badge

    private var confidenceBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(prediction.confidence.displayName)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Factors Section

    private var factorsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.factors)
                .font(.headline)
                .foregroundStyle(.primary)

            if prediction.factors.isEmpty {
                Text(Labels.noFactors)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(prediction.factors, id: \.type) { factor in
                        factorRow(factor)
                    }
                }
            }
        }
    }

    private func factorRow(_ factor: SleepQualityPrediction.PredictionFactor) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: factor.type.iconName)
                .font(.title3)
                .foregroundStyle(factor.impact.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.type.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(factor.detail)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer(minLength: 0)

            impactBadge(factor.impact)
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func impactBadge(_ impact: SleepQualityPrediction.Impact) -> some View {
        Text(impact.badgeLabel)
            .font(.caption2.weight(.medium))
            .foregroundStyle(impact.color)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, 2)
            .background(impact.color.opacity(0.12), in: Capsule())
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.tips)
                .font(.headline)
                .foregroundStyle(.primary)

            if prediction.tips.isEmpty {
                Text(Labels.noTips)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            } else {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(prediction.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: DS.Spacing.sm) {
                            Image(systemName: "lightbulb.fill")
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.caution)
                                .frame(width: 24)
                                .padding(.top, 2)
                            Text(tip)
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(DS.Spacing.sm)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                }
            }
        }
    }

}
