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
            VStack(spacing: DS.Spacing.xl) {
                // Progress Ring + Score
                ZStack {
                    ProgressRingView(
                        progress: Double(score.score) / 100.0,
                        ringColor: score.status.color,
                        lineWidth: 14,
                        size: 160
                    )

                    VStack(spacing: DS.Spacing.xs) {
                        Text("\(animatedScore)")
                            .font(DS.Typography.heroScore)
                            .contentTransition(.numericText())

                        Text(score.status.label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }

                // 7-day sparkline
                if !recentScores.isEmpty {
                    TrendChartView(scores: recentScores)
                        .frame(height: 48)
                        .padding(.horizontal, DS.Spacing.sm)
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
}
