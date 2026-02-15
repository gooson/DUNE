import SwiftUI
import Charts

struct ConditionHeroView: View {
    let score: ConditionScore
    let recentScores: [ConditionScore]

    @State private var animatedScore: Int = 0
    @State private var isAppeared = false

    var body: some View {
        VStack(spacing: 16) {
            // Score + Emoji
            HStack(spacing: 12) {
                Text("\(animatedScore)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                VStack(alignment: .leading) {
                    Text(score.status.emoji)
                        .font(.title)
                    Text(score.status.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            // 7-day Trend (dot + line)
            if !recentScores.isEmpty {
                TrendChartView(scores: recentScores)
                    .frame(height: 60)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            score.status.color.opacity(0.15)
                .animation(.easeInOut(duration: 0.8), value: score.status)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Condition score \(score.score), \(score.status.label)")
        .onAppear {
            guard !isAppeared else { return }
            isAppeared = true
            withAnimation(.easeOut(duration: 1.0)) {
                animatedScore = score.score
            }
        }
        .onChange(of: score.score) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animatedScore = newValue
            }
        }
    }
}
