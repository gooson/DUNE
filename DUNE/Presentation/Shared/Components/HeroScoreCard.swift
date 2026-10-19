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
    var hourlySparkline: HourlySparklineData?
    var trendTitle: LocalizedStringKey = "Trend"

    @State private var animatedScore: Int = 0
    @State private var isAppeared = false
    @State private var showGlow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var desertInk: Color { colorScheme == .dark ? Color(red: 0.957, green: 0.961, blue: 0.933) : Color(red: 0.145, green: 0.169, blue: 0.157) }
    private var desertMuted: Color { colorScheme == .dark ? Color(red: 0.702, green: 0.753, blue: 0.718) : Color(red: 0.337, green: 0.376, blue: 0.357) }

    private var isRegular: Bool { sizeClass == .regular }

    private enum Layout {
        static let ringSizeRegular: CGFloat = 140
        static let ringSizeCompact: CGFloat = 100
        static let ringLineWidthRegular: CGFloat = 14
        static let ringLineWidthCompact: CGFloat = 12
        static let subScoreBarWidthRegular: CGFloat = 48
        static let subScoreBarWidthCompact: CGFloat = 36
    }

    private var ringSize: CGFloat {
        isRegular || dynamicTypeSize.isAccessibilitySize ? Layout.ringSizeRegular : Layout.ringSizeCompact
    }
    private var ringContentSize: CGFloat {
        let innerDiameter = ringSize - ringLineWidth * 2
        // Keep the text rectangle inside the circular opening at large text sizes.
        return dynamicTypeSize.isAccessibilitySize ? innerDiameter / sqrt(2) : innerDiameter
    }
    private var ringLineWidth: CGFloat { isRegular ? Layout.ringLineWidthRegular : Layout.ringLineWidthCompact }
    private var subScoreBarWidth: CGFloat {
        isRegular ? Layout.subScoreBarWidthRegular : Layout.subScoreBarWidthCompact
    }

    var body: some View {
        Group {
            if theme == .desertWarm {
                desertHorizonBody
            } else {
                standardBody
            }
        }
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.impact(weight: .light), trigger: isAppeared)
        .task(id: score) {
            let isFirst = !isAppeared
            isAppeared = true
            animatedScore = 0
            if reduceMotion {
                animatedScore = score
            } else {
                withAnimation(DS.Animation.numeric.delay(isFirst ? 0.2 : 0.1)) {
                    animatedScore = score
                }
                try? await Task.sleep(for: .milliseconds(isFirst ? 800 : 700))
                guard !Task.isCancelled else { return }
                showGlow = true
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                showGlow = false
            }
        }
    }

    private var desertHorizonBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                if scoreLabel == "READINESS" {
                    Text("Activity")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(desertInk)
                } else {
                    Text("Wellness")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(desertInk)
                }
                Spacer()
                if let badgeText {
                    Text(badgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(desertMuted)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 18) {
                    desertScore
                    desertSummary
                }
                VStack(alignment: .leading, spacing: 8) {
                    desertScore
                    desertSummary
                }
            }

            if scoreLabel != "READINESS" {
                HStack(spacing: 6) {
                    Text("View Details")
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(colorScheme == .dark
                    ? Color(red: 0.898, green: 0.678, blue: 0.514)
                    : Color(red: 0.588, green: 0.349, blue: 0.220))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 23)
                .fill(colorScheme == .dark ? Color(red: 0.110, green: 0.120, blue: 0.125) : Color(red: 0.988, green: 0.969, blue: 0.937))
                .overlay(alignment: .bottom) {
                    DesertPreviewWave()
                    .frame(height: 74)
                    .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 23))
                .overlay {
                    RoundedRectangle(cornerRadius: 23)
                        .strokeBorder(colorScheme == .dark
                            ? Color(red: 0.251, green: 0.314, blue: 0.286)
                            : Color(red: 0.871, green: 0.859, blue: 0.824), lineWidth: 1)
                }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
    }

    private var desertScore: some View {
        Text(animatedScore.formatted())
            .font(.system(size: 49, weight: .bold, design: .rounded))
            .foregroundStyle(colorScheme == .dark ? Color(red: 0.478, green: 0.816, blue: 0.678) : Color(red: 0.090, green: 0.431, blue: 0.408))
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private var desertSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(statusLabel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(desertInk)
            Text(guideMessage)
                .font(.subheadline)
                .foregroundStyle(desertMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var standardBody: some View {
        HeroCard(tintColor: statusColor) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if dynamicTypeSize.isAccessibilitySize {
                verticalSummary
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.md) {
                        scoreRing
                        scoreInfo
                            .frame(width: isRegular ? 260 : 145, alignment: .leading)
                        chevron
                    }
                    verticalSummary
                }
            }
            if let sparkline = hourlySparkline, sparkline.points.count >= 2 {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text(trendTitle)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(sparkline.includesYesterday ? "24h" : "Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HourlySparklineView(
                        data: sparkline,
                        tintColor: statusColor,
                        height: isRegular ? 84 : 72,
                        showsReferenceLabels: true,
                        accessibilityTitle: trendTitle
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(trendTitle)
                        .font(.subheadline.weight(.semibold))
                    Text("Not enough data to show trend.")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.72))
                        .frame(maxWidth: .infinity, minHeight: isRegular ? 84 : 72, alignment: .center)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.md) { subScoreItems }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: DS.Spacing.sm) { subScoreItems }
            }
            }
        }
    }

    private var verticalSummary: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack {
                scoreRing
                Spacer(minLength: 0)
                chevron
            }
            scoreInfo
        }
    }

    private var scoreRing: some View {
        ZStack {
            ProgressRingView(
                progress: Double(score) / 100.0,
                ringColor: statusColor,
                lineWidth: ringLineWidth,
                size: ringSize,
                useWarmGradient: true,
                showsTravelingHighlight: true
            )
            .shadow(
                color: statusColor.opacity(showGlow ? 0.5 : 0),
                radius: showGlow ? 12 : 0
            )
            .animation(
                reduceMotion ? .none : DS.Animation.emphasize,
                value: showGlow
            )

            VStack(spacing: 2) {
                Text("\(animatedScore)")
                    .font(DS.Typography.heroScore)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text(scoreLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: ringContentSize, height: ringContentSize)
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

            // Guide message with delta badge
            HStack(spacing: DS.Spacing.xs) {
                Text(guideMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                if let sparkline = hourlySparkline, sparkline.deltaDirection != .stable {
                    ScoreDeltaBadge(
                        delta: sparkline.delta,
                        direction: sparkline.deltaDirection
                    )
                }
            }

        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
    }

    @ViewBuilder
    private var chevron: some View {
        if showsChevron {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.76))
        }
    }

    private var subScoreItems: some View {
        ForEach(Array(subScores.enumerated()), id: \.offset) { _, item in
            subScoreItem(item)
        }
    }

    @ViewBuilder
    private func subScoreItem(_ item: SubScore) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.label)
                .font(.caption2)
                .foregroundStyle(Color.primary.opacity(0.76))

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
                    .foregroundStyle(Color.primary.opacity(item.value != nil ? 0.82 : 0.55))
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}
