import SwiftUI

/// Full detail view for the assessment supplied by Activity.
struct InjuryRiskDetailView: View {
    let assessment: InjuryRiskAssessment?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Labels {
        static let riskFactors = String(localized: "Risk Factors")
        static let recommendations = String(localized: "Recommended Actions")
        static let noFactors = String(localized: "No risk factors detected")
    }

    private var palette: ScoreHeroPalette {
        ScoreHeroPalette(theme: theme, colorScheme: colorScheme)
    }

    var body: some View {
        ScrollView {
            if let assessment {
                VStack(spacing: DS.Spacing.xl) {
                    scoreHero(assessment)
                    factorsSection(assessment)
                    recommendationsSection(assessment)
                }
                .padding()
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            } else {
                emptyState
            }
        }
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Injury Risk")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("activity-injury-risk-detail-screen")
    }

    // MARK: - Actual Assessment

    private func scoreHero(_ assessment: InjuryRiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if dynamicTypeSize.isAccessibilitySize {
                scoreValue(assessment)
                levelStatus(assessment)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: DS.Spacing.xl) {
                        scoreRing(assessment)
                        levelStatus(assessment)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        scoreValue(assessment)
                        levelStatus(assessment)
                    }
                }
            }

            Text(assessment.level.guideMessage)
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.xl)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(palette.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-injury-risk-hero")
    }

    private func scoreRing(_ assessment: InjuryRiskAssessment) -> some View {
        ZStack {
            RiskLevelRing(
                progress: Double(assessment.score) / 100,
                levelColor: assessment.level.color,
                trackColor: palette.ink.opacity(0.18)
            )
            .accessibilityHidden(true)
            scoreValue(assessment)
        }
        .frame(width: 132, height: 132)
    }

    private func scoreValue(_ assessment: InjuryRiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("RISK")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(palette.muted)
            Text("\(assessment.score)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(palette.ink)
                .accessibilityIdentifier("activity-injury-risk-score")
        }
    }

    private func levelStatus(_ assessment: InjuryRiskAssessment) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: assessment.level.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(palette.ink)
                .frame(width: 32, height: 32)
                .background(palette.border, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(assessment.level.color, lineWidth: 2)
                        .allowsHitTesting(false)
                }
                .accessibilityHidden(true)
            Text(assessment.level.displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("activity-injury-risk-level")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Risk Factors

    private func factorsSection(_ assessment: InjuryRiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.riskFactors)
                .font(.headline)

            if assessment.factors.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(DS.Color.positive)
                    Text(Labels.noFactors)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                .accessibilityIdentifier("activity-injury-risk-no-factors")
            } else {
                let maxContribution = assessment.factors.map(\.contribution).max() ?? 1
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(assessment.factors, id: \.type) { factor in
                        factorRow(factor, maxContribution: maxContribution)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-injury-risk-factors")
    }

    private func factorRow(_ factor: InjuryRiskAssessment.RiskFactor, maxContribution: Int) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: factor.type.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DS.Color.activity)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        factorName(factor)
                        factorContribution(factor)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                        factorName(factor)
                        Spacer(minLength: 0)
                        factorContribution(factor)
                    }
                }
                Text(factor.detail)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // A relative comparison with the largest factor, not a risk percentage.
                GeometryReader { geo in
                    let fraction = maxContribution > 0
                        ? CGFloat(factor.contribution) / CGFloat(maxContribution)
                        : 0
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.Color.activity.opacity(0.18))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.Color.activity)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-injury-risk-factor-\(factor.type.rawValue)")
    }

    private func factorName(_ factor: InjuryRiskAssessment.RiskFactor) -> some View {
        Text(factor.type.displayName)
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func factorContribution(_ factor: InjuryRiskAssessment.RiskFactor) -> some View {
        Text("+\(factor.contribution)")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(DS.Color.activity)
            .accessibilityIdentifier("activity-injury-risk-contribution-\(factor.type.rawValue)")
    }

    // MARK: - Recommendations

    private func recommendationsSection(_ assessment: InjuryRiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.recommendations)
                .font(.headline)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(assessment.level.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        if dynamicTypeSize.isAccessibilitySize {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(assessment.level.color)
                                .frame(width: 26, height: 26)
                                .clipped()
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(assessment.level.color)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                        }
                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(
                                "activity-injury-risk-recommendation-\(assessment.level.recommendations.firstIndex(of: recommendation) ?? 0)"
                            )
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-injury-risk-recommendations")
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


// The risk arc uses the full level color on the opaque hero. The shared
// ProgressRingView fades its arc start and remains unchanged for other screens.
private struct RiskLevelRing: View {
    let progress: Double
    let levelColor: Color
    let trackColor: Color

    @State private var displayedProgress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
            Circle()
                .trim(from: 0, to: displayedProgress)
                .stroke(levelColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 132, height: 132)
        .onAppear {
            if reduceMotion {
                displayedProgress = progress
            } else {
                withAnimation(DS.Animation.slow) {
                    displayedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newProgress in
            if reduceMotion {
                displayedProgress = newProgress
            } else {
                withAnimation(DS.Animation.emphasize) {
                    displayedProgress = newProgress
                }
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                displayedProgress = progress
            }
        }
    }
}
