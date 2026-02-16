import SwiftUI
import Charts

struct ConditionHeroView: View {
    let score: ConditionScore
    let recentScores: [ConditionScore]

    @State private var animatedScore: Int = 0
    @State private var isAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HeroCard(tintColor: score.status.color) {
            HStack(spacing: DS.Spacing.xl) {
                // Compact ring
                ZStack {
                    ProgressRingView(
                        progress: Double(score.score) / 100.0,
                        ringColor: score.status.color,
                        lineWidth: 10,
                        size: 88
                    )

                    Text("\(animatedScore)")
                        .font(DS.Typography.cardScore)
                        .contentTransition(.numericText())
                }

                // Score info + sparkline
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    // Status label
                    HStack(spacing: DS.Spacing.xs) {
                        Text(score.status.label)
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(score.status.emoji)
                            .font(.subheadline)
                    }

                    // Guide message
                    Text(score.status.guideMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // 7-day sparkline
                    if !recentScores.isEmpty {
                        HStack(spacing: DS.Spacing.xs) {
                            TrendChartView(scores: recentScores)
                                .frame(height: 32)

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
