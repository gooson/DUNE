import SwiftUI

/// Shared hero score card used by multiple tabs.
struct HeroScoreCard: View {
    struct SubScore {
        let label: String
        let value: Int?
        let maxValue: Int
        let color: Color

        init(label: String, value: Int?, maxValue: Int = 100, color: Color) {
            self.label = label
            self.value = value
            self.maxValue = max(1, maxValue)
            self.color = color
        }
    }

    let score: Int
    let scoreLabel: String
    let statusLabel: String
    let statusIcon: String
    let statusColor: Color
    let guideMessage: String
    let subScores: [SubScore]
    let badgeText: String?
    let showsChevron: Bool
    let accessibilityLabel: String
    let accessibilityHint: String?

    @State private var animatedScore: Int = 0
    @State private var isAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme

    private var isRegular: Bool { sizeClass == .regular }

    private enum Layout {
        static let ringSizeRegular: CGFloat = 140
        static let ringSizeCompact: CGFloat = 100
        static let ringLineWidthRegular: CGFloat = 14
        static let ringLineWidthCompact: CGFloat = 12
        static let subScoreBarWidthRegular: CGFloat = 48
        static let subScoreBarWidthCompact: CGFloat = 36
        // Correction #83 — cached gradients for score text (per-theme)
        static let desertScoreGradient = LinearGradient(
            colors: [DS.Color.desertBronze, DS.Color.desertDusk],
            startPoint: .top,
            endPoint: .bottom
        )
        static let oceanScoreGradient = LinearGradient(
            colors: [Color("OceanBronze"), Color("OceanDusk")],
            startPoint: .top,
            endPoint: .bottom
        )
        static let forestScoreGradient = LinearGradient(
            colors: [Color("ForestBronze"), Color("ForestDusk")],
            startPoint: .top,
            endPoint: .bottom
        )
        static func scoreGradient(for theme: AppTheme) -> LinearGradient {
            switch theme {
            case .desertWarm:  desertScoreGradient
            case .oceanCool:   oceanScoreGradient
            case .forestGreen: forestScoreGradient
            }
        }
    }

    private var ringSize: CGFloat { isRegular ? Layout.ringSizeRegular : Layout.ringSizeCompact }
    private var ringLineWidth: CGFloat { isRegular ? Layout.ringLineWidthRegular : Layout.ringLineWidthCompact }
    private var subScoreBarWidth: CGFloat {
        isRegular ? Layout.subScoreBarWidthRegular : Layout.subScoreBarWidthCompact
    }

    var body: some View {
        HeroCard(tintColor: statusColor) {
            HStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                scoreRing
                scoreInfo

                Spacer(minLength: 0)

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
        .sensoryFeedback(.impact(weight: .light), trigger: isAppeared)
        .onAppear {
            let isFirst = !isAppeared
            isAppeared = true
            animatedScore = 0
            if reduceMotion {
                animatedScore = score
            } else {
                withAnimation(DS.Animation.numeric.delay(isFirst ? 0.2 : 0.1)) {
                    animatedScore = score
                }
            }
        }
        .onChange(of: score) { _, newValue in
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
                progress: Double(score) / 100.0,
                ringColor: statusColor,
                lineWidth: ringLineWidth,
                size: ringSize,
                useWarmGradient: true
            )

            VStack(spacing: 2) {
                Text("\(animatedScore)")
                    .font(DS.Typography.heroScore)
                    .foregroundStyle(Layout.scoreGradient(for: theme))
                    .contentTransition(.numericText())

                Text(scoreLabel)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.sandColor)
                    .tracking(1)
            }
        }
    }

    private var scoreInfo: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                Text(statusLabel)
                    .font(isRegular ? .title3 : .headline)
                    .fontWeight(.semibold)

                Image(systemName: statusIcon)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)

                if let badgeText {
                    Text(badgeText)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.quaternary))
                }
            }

            Text(guideMessage)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.Spacing.md) {
                ForEach(Array(subScores.enumerated()), id: \.offset) { _, item in
                    subScoreItem(item)
                }
            }
        }
    }

    @ViewBuilder
    private func subScoreItem(_ item: SubScore) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.label)
                .font(.caption2)
                .foregroundStyle(theme.sandColor)

            HStack(spacing: DS.Spacing.xs) {
                GeometryReader { geo in
                    let resolved = max(0, min(item.value ?? 0, item.maxValue))
                    let fraction = CGFloat(resolved) / CGFloat(item.maxValue)
                    Capsule()
                        .fill(item.color.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(item.color)
                                .frame(width: geo.size.width * fraction)
                        }
                }
                .frame(width: subScoreBarWidth, height: 4)

                Text(item.value.map { "\($0)" } ?? "--")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(item.value != nil ? AnyShapeStyle(theme.sandColor) : AnyShapeStyle(.quaternary))
                    .monospacedDigit()
            }
        }
    }
}
