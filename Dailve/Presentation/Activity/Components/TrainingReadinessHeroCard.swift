import SwiftUI

struct TrainingReadinessHeroCard: View {
    let readiness: TrainingReadiness?
    let isCalibrating: Bool

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
        if let readiness {
            filledCard(readiness)
        } else {
            emptyCard
        }
    }

    // MARK: - Filled State

    @ViewBuilder
    private func filledCard(_ readiness: TrainingReadiness) -> some View {
        HeroCard(tintColor: readiness.status.color) {
            HStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // Score ring
                ZStack {
                    ProgressRingView(
                        progress: Double(readiness.score) / 100.0,
                        ringColor: readiness.status.color,
                        lineWidth: ringLineWidth,
                        size: ringSize
                    )

                    VStack(spacing: 2) {
                        Text("\(animatedScore)")
                            .font(DS.Typography.heroScore)
                            .contentTransition(.numericText())

                        Text("READINESS")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .tracking(1)
                    }
                }

                // Score info
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Status label + calibrating badge
                    HStack(spacing: DS.Spacing.xs) {
                        Text(readiness.status.label)
                            .font(isRegular ? .title3 : .headline)
                            .fontWeight(.semibold)

                        Image(systemName: readiness.status.iconName)
                            .font(.subheadline)
                            .foregroundStyle(readiness.status.color)

                        if isCalibrating {
                            Text("Calibrating")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.quaternary))
                        }
                    }

                    // Guide message
                    Text(readiness.status.guideMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Sub-scores
                    subScoresView(readiness.components)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Training readiness \(readiness.score), \(readiness.status.label)")
        .sensoryFeedback(.impact(weight: .light), trigger: isAppeared)
        .onAppear {
            let isFirst = !isAppeared
            isAppeared = true
            animatedScore = 0
            if reduceMotion {
                animatedScore = readiness.score
            } else {
                withAnimation(DS.Animation.numeric.delay(isFirst ? 0.2 : 0.1)) {
                    animatedScore = readiness.score
                }
            }
        }
        .onChange(of: readiness.score) { _, newValue in
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

    @ViewBuilder
    private func subScoresView(_ components: TrainingReadiness.Components) -> some View {
        HStack(spacing: DS.Spacing.md) {
            subScoreItem(label: "HRV", value: components.hrvScore, color: DS.Color.hrv)
            subScoreItem(label: "Sleep", value: components.sleepScore, color: DS.Color.sleep)
            subScoreItem(label: "Recovery", value: components.fatigueScore, color: DS.Color.activity)
        }
    }

    @ViewBuilder
    private func subScoreItem(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: DS.Spacing.xs) {
                // Mini bar
                GeometryReader { geo in
                    let fraction = CGFloat(value) / 100.0
                    Capsule()
                        .fill(color.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * fraction)
                        }
                }
                .frame(width: isRegular ? 48 : 36, height: 4)

                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Empty State

    private var emptyCard: some View {
        HeroCard(tintColor: DS.Color.activity.opacity(0.5)) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "figure.run")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)

                Text("Need More Data")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Track your workouts and wear Apple Watch to see your training readiness score.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
        }
    }
}
