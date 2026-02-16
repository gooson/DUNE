import SwiftUI
import Charts

struct ConditionHeroView: View {
    let score: ConditionScore
    let recentScores: [ConditionScore]

    @State private var animatedScore: Int = 0
    @State private var isAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    private enum Layout {
        static let ringSizeRegular: CGFloat = 128
        static let ringSizeCompact: CGFloat = 88
        static let ringLineWidthRegular: CGFloat = 14
        static let ringLineWidthCompact: CGFloat = 10
        static let sparklineHeightRegular: CGFloat = 56
        static let sparklineHeightCompact: CGFloat = 44
    }

    private var ringSize: CGFloat { isRegular ? Layout.ringSizeRegular : Layout.ringSizeCompact }
    private var ringLineWidth: CGFloat { isRegular ? Layout.ringLineWidthRegular : Layout.ringLineWidthCompact }

    var body: some View {
        HeroCard(tintColor: score.status.color) {
            HStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // Compact ring
                ZStack {
                    ProgressRingView(
                        progress: Double(score.score) / 100.0,
                        ringColor: score.status.color,
                        lineWidth: ringLineWidth,
                        size: ringSize
                    )

                    Text("\(animatedScore)")
                        .font(DS.Typography.cardScore)
                        .contentTransition(.numericText())
                }

                // Score info + sparkline
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

                    // Guide message
                    Text(score.status.guideMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // 7-day sparkline
                    if !recentScores.isEmpty {
                        HStack(spacing: DS.Spacing.xs) {
                            TrendChartView(scores: recentScores)
                                .frame(height: isRegular ? Layout.sparklineHeightRegular : Layout.sparklineHeightCompact)

                            Text("7d")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer(minLength: 0)
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
}
