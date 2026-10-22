import SwiftUI

/// The shared Today composition from the eight theme directions: one surface
/// contains the score, its trend, the supporting signals, and a single detail destination.
struct DesertHorizonConditionHeroView: View {
    let score: ConditionScore
    let trendBadges: [BaselineDetail]
    let hourlySparkline: HourlySparklineData?
    let recentScores: [ConditionScore]
    let adaptiveMessage: AdaptiveHeroMessage?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var isDesert: Bool { theme == .desertWarm }
    /// Every direction preview uses an opaque dark Today hero in both appearances.
    private var surface: Color {
        switch theme {
        case .desertWarm: Color(red: 0.208, green: 0.180, blue: 0.161)
        case .oceanCool: Color(red: 0.063, green: 0.165, blue: 0.231)
        case .forestGreen: Color(red: 0.114, green: 0.208, blue: 0.153)
        case .sakuraCalm: Color(red: 0.282, green: 0.176, blue: 0.243)
        case .arcticDawn: Color(red: 0.082, green: 0.161, blue: 0.263)
        case .solarPop: Color(red: 0.243, green: 0.157, blue: 0.153)
        case .contourAtlas: Color(red: 0.157, green: 0.188, blue: 0.161)
        case .waterLilies: Color(red: 0.188, green: 0.212, blue: 0.286)
        }
    }
    private var border: Color {
        switch theme {
        case .desertWarm: Color(red: 0.455, green: 0.365, blue: 0.263)
        case .oceanCool: Color(red: 0.227, green: 0.400, blue: 0.478)
        case .forestGreen: Color(red: 0.298, green: 0.416, blue: 0.298)
        case .sakuraCalm: Color(red: 0.588, green: 0.420, blue: 0.510)
        case .arcticDawn: Color(red: 0.318, green: 0.439, blue: 0.557)
        case .solarPop: Color(red: 0.596, green: 0.376, blue: 0.282)
        case .contourAtlas: Color(red: 0.380, green: 0.455, blue: 0.318)
        case .waterLilies: Color(red: 0.408, green: 0.463, blue: 0.549)
        }
    }
    private var gold: Color { isDesert ? Color(red: 0.886, green: 0.718, blue: 0.380) : theme.accentColor }
    private var paleGold: Color { isDesert ? Color(red: 0.969, green: 0.843, blue: 0.471) : theme.duskColor }
    /// The card stays dark in light appearance, while these three themes use
    /// dark accents on the surrounding light canvas.
    private var heroAccent: Color {
        guard colorScheme == .light else { return gold }
        return switch theme {
        case .sakuraCalm: Color(red: 0.992, green: 0.545, blue: 0.735)
        case .contourAtlas: Color(red: 0.808, green: 0.910, blue: 0.514)
        case .waterLilies: Color(red: 0.906, green: 0.667, blue: 0.792)
        default: gold
        }
    }
    private var heroHighlight: Color {
        if colorScheme == .light && (theme == .sakuraCalm || theme == .contourAtlas || theme == .waterLilies) {
            return ink
        }
        return paleGold
    }
    private var heroPositive: Color {
        if colorScheme == .light && theme == .contourAtlas {
            return Color(red: 0.741, green: 0.835, blue: 0.525)
        }
        if colorScheme == .light && theme == .waterLilies {
            return Color(red: 0.502, green: 0.722, blue: 0.478)
        }
        return theme.scoreGood
    }
    private var muted: Color { isDesert ? Color(red: 0.831, green: 0.784, blue: 0.722) : ink.opacity(0.76) }
    private var ink: Color {
        switch theme {
        case .desertWarm: Color(red: 1, green: 0.961, blue: 0.910)
        case .oceanCool: Color(red: 0.941, green: 0.984, blue: 1)
        case .forestGreen: Color(red: 0.969, green: 0.965, blue: 0.910)
        case .sakuraCalm: Color(red: 1, green: 0.969, blue: 0.980)
        case .arcticDawn: Color(red: 0.969, green: 0.988, blue: 1)
        case .solarPop: Color(red: 1, green: 0.973, blue: 0.929)
        case .contourAtlas: Color(red: 0.953, green: 0.973, blue: 0.914)
        case .waterLilies: Color(red: 1, green: 0.965, blue: 0.984)
        }
    }

    var body: some View {
        NavigationLink(value: score) {
            VStack(alignment: .leading, spacing: 18) {
                header
                Rectangle()
                    .fill(isDesert ? Color(red: 0.412, green: 0.341, blue: 0.278) : gold.opacity(0.25))
                    .frame(height: 1)
                trend
                    .accessibilityIdentifier("dashboard-hero-trend")
                evidence
                HStack(spacing: 6) {
                    Spacer()
                    Text("Condition Details")
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(heroAccent)
                .frame(minHeight: 44)
            }
            .contentShape(Rectangle())
            .padding(21)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard-hero-condition")
        .accessibilityHint("Opens condition details")
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(border, lineWidth: 1)
                }
                .shadow(color: Color(red: 0.455, green: 0.357, blue: 0.196).opacity(0.16), radius: 16, y: 9)
        }
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 18) {
                    ring
                    statusText
                }
            } else {
                HStack(alignment: .center, spacing: 18) {
                    ring
                    statusText
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var ring: some View {
        TabHeroScoreRing(
            progress: Double(score.score) / 100,
            value: score.score.formatted(),
            caption: "CONDITION",
            ringColor: heroAccent,
            highlightColor: heroHighlight,
            tipColor: heroPositive,
            trackColor: isDesert ? Color(red: 0.435, green: 0.353, blue: 0.227) : heroAccent,
            textColor: ink,
            secondaryTextColor: muted,
            accessibilityLabel: "Condition score \(score.score), \(score.status.label)",
            accessibilityIdentifier: "dashboard-hero-ring"
        )
    }

    private var statusText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Condition")
                .font(.caption.weight(.bold))
                .foregroundStyle(heroAccent)
            Text(score.status.guideMessage)
                .font(.title3.weight(.bold))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(adaptiveMessage?.message ?? score.narrativeMessage)
                .font(.subheadline)
                .foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Condition Trend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(trendPeriod)
                    .font(.caption)
                    .foregroundStyle(muted)
            }
            .foregroundStyle(ink)

            if let hourlySparkline, hourlySparkline.points.count >= 2 {
                HourlySparklineView(data: hourlySparkline, tintColor: heroHighlight, height: 72, usesTimelineAxis: true)
            } else if hasWeeklyTrend {
                TrendChartView(scores: recentScores, lineColor: heroHighlight)
                    .frame(height: 126)
            } else {
                Text("Not enough data to show trend.")
                    .font(.subheadline)
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
    }

    private var trendPeriod: String {
        if let hourlySparkline, hourlySparkline.points.count >= 2 {
            return hourlySparkline.includesYesterday ? "24h" : "Today"
        }
        return hasWeeklyTrend ? "7d" : ""
    }

    private var hasWeeklyTrend: Bool {
        recentScores.count >= 2 && recentScores.first?.date != recentScores.last?.date
    }

    private var evidence: some View {
        HStack(spacing: 8) {
            ForEach(Array(trendBadges.prefix(2).enumerated()), id: \.offset) { _, detail in
                HStack(spacing: 4) {
                    Text(detail.label)
                        .foregroundStyle(ink)
                    Text(detail.value.formattedWithSeparator(fractionDigits: detail.fractionDigits))
                        .foregroundStyle(heroPositive)
                }
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(isDesert ? Color(red: 0.290, green: 0.251, blue: 0.208) : gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            Spacer(minLength: 0)
        }
    }
}
