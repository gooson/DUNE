import SwiftUI
import Charts

struct ConditionHeroView: View {
    let score: ConditionScore
    let recentScores: [ConditionScore]
    var weeklyGoalProgress: (completedDays: Int, goalDays: Int)? = nil
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
        static let sparklineHeightRegular: CGFloat = 56
        static let sparklineHeightCompact: CGFloat = 44
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
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        scoreRing
                            .frame(maxWidth: .infinity)
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Condition score \(score.score), \(score.status.label)")
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
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.sandColor)
                    .tracking(1)
            }
            .frame(width: ringContentSize, height: ringContentSize)
        }
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

            // Hourly sparkline (today) or 7-day sparkline (fallback)
            if let sparkline = hourlySparkline, !sparkline.points.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    HourlySparklineView(data: sparkline, tintColor: score.status.color)
                        .frame(height: isRegular ? Layout.sparklineHeightRegular : Layout.sparklineHeightCompact)

                    Text(sparkline.includesYesterday ? "24h" : "Today")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextStyle)
                }
            } else if !recentScores.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    TrendChartView(scores: recentScores)
                        .frame(height: isRegular ? Layout.sparklineHeightRegular : Layout.sparklineHeightCompact)

                    Text("7d")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextStyle)
                }
            }

            if let weeklyGoalProgress {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Weekly Goal")
                            .font(.caption2)
                            .foregroundStyle(theme.tertiaryTextStyle)
                        Spacer()
                        Text("\(weeklyGoalProgress.completedDays)/\(weeklyGoalProgress.goalDays)")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryTextColor)
                            .monospacedDigit()
                    }
                    ProgressView(
                        value: Double(weeklyGoalProgress.completedDays),
                        total: Double(max(1, weeklyGoalProgress.goalDays))
                    )
                    .tint(DS.Color.activity)
                }
            }

            if !trendBadges.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    ForEach(Array(trendBadges.enumerated()), id: \.offset) { _, detail in
                        BaselineTrendBadge(detail: detail)
                    }
                }
            }
        }
    }
}
