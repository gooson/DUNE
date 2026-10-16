import SwiftUI
import Charts

struct ConditionHeroView: View {
    let score: ConditionScore
    let recentScores: [ConditionScore]
    var trendBadges: [BaselineDetail] = []
    var hourlySparkline: HourlySparklineData?
    var adaptiveMessage: AdaptiveHeroMessage? = nil

    private enum Labels {
        static let scoreLabel = "CONDITION"
    }

    @State private var animatedScore: Int = 0
    @State private var isAppeared = false
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isRegular: Bool { sizeClass == .regular }

    private enum Layout {
        static let ringSizeRegular: CGFloat = 128
        static let ringSizeCompact: CGFloat = 88
        static let ringLineWidthRegular: CGFloat = 14
        static let ringLineWidthCompact: CGFloat = 10
        static let sparklineHeightRegular: CGFloat = 84
        static let sparklineHeightCompact: CGFloat = 72
    }

    private var ringSize: CGFloat {
        isRegular || dynamicTypeSize.isAccessibilitySize ? Layout.ringSizeRegular : Layout.ringSizeCompact
    }
    private var ringContentSize: CGFloat {
        let innerDiameter = ringSize - ringLineWidth * 2
        return dynamicTypeSize.isAccessibilitySize ? innerDiameter / sqrt(2) : innerDiameter
    }
    private var ringLineWidth: CGFloat { isRegular ? Layout.ringLineWidthRegular : Layout.ringLineWidthCompact }

    var body: some View {
        HeroCard(tintColor: score.status.color) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            scoreRing.frame(maxWidth: .infinity)
                            scoreDetails
                        }
                    } else {
                        HStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                            scoreRing
                            scoreDetails
                            Spacer(minLength: 0)
                        }
                    }
                }

                trendContent
                    .accessibilityIdentifier("dashboard-hero-trend")

                if !trendBadges.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(Array(trendBadges.prefix(2).enumerated()), id: \.offset) { _, detail in
                            BaselineTrendBadge(detail: detail)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.impact(weight: .light), trigger: isAppeared)
        .onAppear {
            guard !isAppeared else { return }
            isAppeared = true
            if reduceMotion {
                animatedScore = score.score
            } else {
                withAnimation(DS.Animation.numeric.delay(0.2)) {
                    animatedScore = score.score
                }
            }
        }
        .onChange(of: score.score) { _, newValue in
            if reduceMotion {
                animatedScore = newValue
            } else {
                withAnimation(DS.Animation.numeric) {
                    animatedScore = newValue
                }
            }
        }
    }

    private var scoreRing: some View {
        ZStack {
            ProgressRingView(
                progress: Double(score.score) / 100.0,
                ringColor: score.status.color,
                lineWidth: ringLineWidth,
                size: ringSize,
                useWarmGradient: true,
                showsTravelingHighlight: true,
                gradientTipColor: score.status.nextTierColor
            )

            VStack(spacing: 2) {
                Text("\(animatedScore)")
                    .font(DS.Typography.cardScore)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(theme.detailScoreGradient)
                    .contentTransition(.numericText())

                Text(Labels.scoreLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.sandColor)
                    .tracking(1)
            }
            .frame(width: ringContentSize, height: ringContentSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Condition score \(score.score), \(score.status.label)")
    }

    private var scoreDetails: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Status label with SF Symbol
            HStack(spacing: DS.Spacing.xs) {
                Text(score.status.label)
                    .font(isRegular ? .title3 : .headline)
                    .fontWeight(.semibold)

                Image(systemName: score.status.iconName)
                    .font(.subheadline)
                    .foregroundStyle(score.status.color)
            }

            // Guide message with delta badge
            HStack(spacing: DS.Spacing.xs) {
                if let adaptive = adaptiveMessage {
                    Image(systemName: adaptive.icon)
                        .font(.caption)
                        .foregroundStyle(score.status.color)

                    Text(adaptive.message)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(score.narrativeMessage)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let sparkline = hourlySparkline, sparkline.deltaDirection != .stable {
                    ScoreDeltaBadge(
                        delta: sparkline.delta,
                        direction: sparkline.deltaDirection
                    )
                }
            }

        }
    }

    @ViewBuilder
    private var trendContent: some View {
        if let sparkline = hourlySparkline, !sparkline.points.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Text("Condition Trend")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if sparkline.includesYesterday {
                        Text("24h")
                    } else {
                        Text("Today")
                    }
                }
                .foregroundStyle(.primary)
                HourlySparklineView(
                    data: sparkline,
                    tintColor: score.status.color,
                    height: isRegular ? Layout.sparklineHeightRegular : Layout.sparklineHeightCompact
                )
                .accessibilityLabel("Condition Trend")
            }
        } else if !recentScores.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Text("Condition Trend")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("7d")
                }
                .foregroundStyle(.primary)
                TrendChartView(scores: recentScores)
                    .frame(height: isRegular ? Layout.sparklineHeightRegular : Layout.sparklineHeightCompact)
                    .accessibilityLabel("Condition Trend")
            }
        } else {
            Text("Not enough data to show trend.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryTextColor)
        }
    }
}
