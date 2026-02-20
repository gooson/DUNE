import SwiftUI

struct WellnessHeroCard: View {
    let score: WellnessScore?
    let sleepScore: Int?
    let conditionScore: Int?
    let bodyScore: Int?

    @State private var animatedScore: Int = 0
    @State private var isAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    private enum Layout {
        static let ringSizeRegular: CGFloat = 140
        static let ringSizeCompact: CGFloat = 100
        static let ringLineWidthRegular: CGFloat = 14
        static let ringLineWidthCompact: CGFloat = 12
    }

    private var ringSize: CGFloat { isRegular ? Layout.ringSizeRegular : Layout.ringSizeCompact }
    private var ringLineWidth: CGFloat { isRegular ? Layout.ringLineWidthRegular : Layout.ringLineWidthCompact }

    var body: some View {
        if let score {
            filledCard(score)
        } else {
            emptyCard
        }
    }

    // MARK: - Filled State

    @ViewBuilder
    private func filledCard(_ score: WellnessScore) -> some View {
        HeroCard(tintColor: score.status.color) {
            HStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // Score ring
                ZStack {
                    ProgressRingView(
                        progress: Double(score.score) / 100.0,
                        ringColor: score.status.color,
                        lineWidth: ringLineWidth,
                        size: ringSize
                    )

                    VStack(spacing: 2) {
                        Text("\(animatedScore)")
                            .font(DS.Typography.heroScore)
                            .contentTransition(.numericText())

                        Text("WELLNESS")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .tracking(1)
                    }
                }

                // Score info
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Status label
                    HStack(spacing: DS.Spacing.xs) {
                        Text(score.status.label)
                            .font(isRegular ? .title3 : .headline)
                            .fontWeight(.semibold)

                        Image(systemName: score.status.iconName)
                            .font(.subheadline)
                            .foregroundStyle(score.status.color)
                    }

                    // Guide message
                    Text(score.guideMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Sub-scores
                    subScoresView
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wellness score \(score.score), \(score.status.label)")
        .accessibilityHint("Tap to see score details")
        .sensoryFeedback(.impact(weight: .light), trigger: isAppeared)
        .onAppear {
            let isFirst = !isAppeared
            isAppeared = true
            animatedScore = 0
            if reduceMotion {
                animatedScore = score.score
            } else {
                withAnimation(DS.Animation.numeric.delay(isFirst ? 0.2 : 0.1)) {
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

    // MARK: - Sub-Scores

    private var subScoresView: some View {
        HStack(spacing: DS.Spacing.md) {
            subScoreItem(label: "Sleep", value: sleepScore, color: DS.Color.sleep)
            subScoreItem(label: "Condition", value: conditionScore, color: DS.Color.hrv)
            subScoreItem(label: "Body", value: bodyScore, color: DS.Color.body)
        }
    }

    @ViewBuilder
    private func subScoreItem(label: String, value: Int?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: DS.Spacing.xs) {
                // Mini bar
                GeometryReader { geo in
                    let fraction = CGFloat(value ?? 0) / 100.0
                    Capsule()
                        .fill(color.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * fraction)
                        }
                }
                .frame(width: isRegular ? 48 : 36, height: 4)

                Text(value.map { "\($0)" } ?? "--")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(value != nil ? .primary : .quaternary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Empty State

    private var emptyCard: some View {
        HeroCard(tintColor: DS.Color.fitness.opacity(0.5)) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)

                Text("Need More Data")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Wear your Apple Watch tonight to start tracking your wellness score.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
        }
    }
}
