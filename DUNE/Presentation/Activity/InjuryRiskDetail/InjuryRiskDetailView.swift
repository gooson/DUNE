import SwiftUI

/// Full detail view for Injury Risk Assessment — all factors, contribution bars, recommendations.
struct InjuryRiskDetailView: View {
    let assessment: InjuryRiskAssessment?

    private enum Labels {
        static let riskFactors = String(localized: "Risk Factors")
        static let recommendations = String(localized: "Recommended Actions")
        static let noFactors = String(localized: "No risk factors detected")
    }

    var body: some View {
        ScrollView {
            if let assessment {
                VStack(spacing: DS.Spacing.lg) {
                    scoreHero(assessment)
                    factorsSection(assessment)
                    recommendationsSection(assessment)
                }
                .padding()
            } else {
                emptyState
            }
        }
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Injury Risk")
        .accessibilityIdentifier("activity-injury-risk-detail-screen")
    }

    // MARK: - Score Hero

    private func scoreHero(_ assessment: InjuryRiskAssessment) -> some View {
        DetailScoreHero(
            score: assessment.score,
            scoreLabel: "RISK",
            statusLabel: assessment.level.displayName,
            statusIcon: assessment.level.iconName,
            statusColor: assessment.level.color,
            guideMessage: assessment.level.guideMessage
        )
    }

    // MARK: - Factors Section

    private func factorsSection(_ assessment: InjuryRiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.riskFactors)
                .font(.headline)
                .foregroundStyle(.primary)

            if assessment.factors.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(DS.Color.positive)
                    Text(Labels.noFactors)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    let maxContribution = assessment.factors.map(\.contribution).max() ?? 1
                    ForEach(assessment.factors, id: \.type) { factor in
                        factorRow(factor, maxContribution: maxContribution)
                    }
                }
            }
        }
    }

    private func factorRow(_ factor: InjuryRiskAssessment.RiskFactor, maxContribution: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: factor.type.iconName)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.activity)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(factor.type.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(factor.detail)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                Spacer(minLength: 0)
                Text("+\(factor.contribution)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(DS.Color.activity)
            }

            // Contribution bar
            GeometryReader { geo in
                let fraction = maxContribution > 0
                    ? CGFloat(factor.contribution) / CGFloat(maxContribution)
                    : 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Color.activity.opacity(0.3))
                    .frame(width: geo.size.width * fraction, height: 4)
            }
            .frame(height: 4)
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Recommendations Section

    private func recommendationsSection(_ assessment: InjuryRiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.recommendations)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(assessment.level.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(assessment.level.color)
                            .padding(.top, 2)
                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "shield.checkered")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("Train for a few days to see your injury risk assessment.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
