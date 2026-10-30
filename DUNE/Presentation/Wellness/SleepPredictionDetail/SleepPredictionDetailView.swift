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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title3) private var confidenceIconSize: CGFloat = 22

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }
    private var scoreAccessibilityLabel: String {
        String(localized: "Sleep score \(prediction.predictedScore), \(prediction.outlook.displayName)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                scoreHero
                confidenceCard
                factorsSection
                tipsSection
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.lg)
        }
        .accessibilityIdentifier("wellness-sleep-prediction-detail-screen")
        .background {
            DetailWaveBackground()
                .environment(\.waveColor, DS.Color.sleep)
        }
        .englishNavigationTitle("Tonight's Sleep")
    }

    // MARK: - Score Hero

    private var scoreHero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Label {
                Text("SLEEP")
            } icon: {
                Image(systemName: prediction.outlook.iconName)
                    .foregroundStyle(palette.ink)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.heroAccent)
            .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                Text(prediction.predictedScore.formatted())
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .accessibilityIdentifier("sleep-prediction-hero-score")
                    .accessibilityLabel(Text(scoreAccessibilityLabel))
                heroStatus
            } else {
                HStack(spacing: DS.Spacing.lg) {
                    CompactConditionRing(
                        score: prediction.predictedScore,
                        ringColor: palette.heroAccent,
                        highlightColor: palette.heroHighlight,
                        tipColor: palette.heroPositive,
                        trackColor: palette.track,
                        textColor: palette.ink,
                        accessibilityLabel: LocalizedStringKey(scoreAccessibilityLabel),
                        accessibilityIdentifier: "sleep-prediction-hero-score"
                    )
                    heroStatus
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    LinearGradient(colors: [palette.heroAccent.opacity(0.28), .clear],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                    DesertDuneOverlayView(color: palette.heroHighlight, opacity: 0.12,
                                          amplitude: 0.12, frequency: 0.7, verticalOffset: 0.60,
                                          bottomFade: 0, driftDuration: 0,
                                          crestColor: palette.heroAccent, crestOpacity: 0.20)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleep-prediction-hero")
    }

    private var heroStatus: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(prediction.outlook.displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.ink)
                .accessibilityIdentifier("sleep-prediction-hero-status")
            Text(prediction.outlook.guideMessage)
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("sleep-prediction-hero-guide")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confidenceLevel: Int {
        switch prediction.confidence {
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }

    private var confidenceCard: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Spacing.lg))
        return layout {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: min(confidenceIconSize, 32), weight: .semibold))
                    .foregroundStyle(DS.Color.sleep)
                    .accessibilityHidden(true)
                Text(prediction.confidence.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("sleep-prediction-confidence-label")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index < confidenceLevel ? DS.Color.sleep : DS.Color.sleep.opacity(0.18))
                        .frame(width: 28, height: 8)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(DS.Spacing.xl)
        .background(DS.Color.sleep.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Color.sleep.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleep-prediction-confidence")
    }

    // MARK: - Factors Section

    private var factorsSection: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(Labels.factors)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("sleep-prediction-factors-title")

                if prediction.factors.isEmpty {
                    Text(Labels.noFactors)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("sleep-prediction-no-factors")
                } else {
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(prediction.factors, id: \.type) { factor in
                            factorRow(factor)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleep-prediction-factors")
    }

    private func factorRow(_ factor: SleepQualityPrediction.PredictionFactor) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Spacing.md))
        return layout {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: factor.type.iconName)
                    .font(.title3)
                    .foregroundStyle(factor.impact.color)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(factor.type.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("sleep-prediction-factor-title-\(factor.type.rawValue)")
                    Text(factor.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("sleep-prediction-factor-detail-\(factor.type.rawValue)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            impactBadge(factor.impact)
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.sleep.opacity(0.07), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleep-prediction-factor-\(factor.type.rawValue)")
    }

    private func impactBadge(_ impact: SleepQualityPrediction.Impact) -> some View {
        Text(impact.badgeLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(impact.color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(impact.color.opacity(0.12), in: Capsule())
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(Labels.tips)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("sleep-prediction-tips-title")

                if prediction.tips.isEmpty {
                    Text(Labels.noTips)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("sleep-prediction-no-tips")
                } else {
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(prediction.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.title3)
                                    .foregroundStyle(DS.Color.caution)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(DS.Spacing.md)
                            .background(DS.Color.caution.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleep-prediction-tips")
    }

}
