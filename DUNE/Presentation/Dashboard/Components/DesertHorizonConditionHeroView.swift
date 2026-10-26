import SwiftUI

/// Today Compact keeps the score, trend, and baseline evidence in one detail destination.
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
            VStack(alignment: .leading, spacing: 12) {
                titleRow
                header
                trend
                if !trendBadges.isEmpty {
                    Rectangle()
                        .fill(isDesert ? Color(red: 0.412, green: 0.341, blue: 0.278) : gold.opacity(0.25))
                        .frame(height: 1)
                    evidence
                }
            }
            .contentShape(Rectangle())
            .padding(16)
        }
        .buttonStyle(CardNavigationButtonStyle())
        .accessibilityIdentifier("dashboard-hero-condition")
        .accessibilityHint("View Details")
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

    private var titleRow: some View {
        CardNavigationHeader(minimumHeight: 0) {
            Text("CONDITION")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(heroAccent)
        }
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    Text(score.score.formatted())
                        .font(.largeTitle.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(scoreAccessibilityLabel))
                        .accessibilityIdentifier("dashboard-hero-score")
                    statusText
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    ring
                    statusText
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var ring: some View {
        CompactConditionRing(
            score: score.score,
            ringColor: heroAccent,
            highlightColor: heroHighlight,
            tipColor: heroPositive,
            trackColor: isDesert ? Color(red: 0.435, green: 0.353, blue: 0.227) : heroAccent,
            textColor: ink,
            accessibilityLabel: scoreAccessibilityLabel
        )
    }

    private var scoreAccessibilityLabel: LocalizedStringKey {
        "Condition score \(score.score), \(score.status.label)"
    }

    private var statusText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(score.status.guideMessage)
                .font(.headline.weight(.semibold))
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
                    .accessibilityIdentifier("dashboard-hero-trend")
                Spacer()
                Text(trendPeriod)
                    .font(.caption)
                    .foregroundStyle(muted)
            }
            .foregroundStyle(ink)

            if let validHourlySparkline {
                HourlySparklineView(
                    data: validHourlySparkline,
                    tintColor: heroHighlight,
                    height: 48,
                    showsArea: false,
                    showsTimeRange: true,
                    usesTimelineAxis: true,
                    anchorsTimelineToNow: true
                )
                .accessibilityIdentifier("dashboard-hourly-condition-chart")
            } else if hasWeeklyTrend {
                TrendChartView(
                    scores: weeklyTrendScores,
                    lineColor: heroHighlight,
                    labelColor: muted,
                    referenceColor: muted.opacity(0.55),
                    compact: true
                )
            } else {
                Text("Not enough data to show trend.")
                    .font(.subheadline)
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
    }

    private var trendPeriod: LocalizedStringKey {
        if let validHourlySparkline {
            return validHourlySparkline.includesYesterday ? "24h" : "Today"
        }
        return hasWeeklyTrend ? "7d" : ""
    }

    private var validHourlySparkline: HourlySparklineData? {
        guard let hourlySparkline, hourlySparkline.points.count >= 2,
              hourlySparkline.currentScore.isFinite,
              hourlySparkline.points.last?.score.isFinite == true,
              Int(hourlySparkline.currentScore.rounded()) == score.score,
              Int((hourlySparkline.points.last?.score ?? -1).rounded()) == score.score else { return nil }
        return hourlySparkline
    }

    private var hasWeeklyTrend: Bool {
        weeklyTrendScores.count >= 2
    }

    private var weeklyTrendScores: [ConditionScore] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let firstDay = calendar.date(byAdding: .day, value: -6, to: today),
              let nextDay = calendar.date(byAdding: .day, value: 1, to: today),
              score.date >= firstDay, score.date < nextDay else { return [] }

        var scores = [score]
        var seenDays: Set<Date> = [calendar.startOfDay(for: score.date)]
        let history = recentScores
            .filter { $0.date >= firstDay && $0.date < nextDay }
            .sorted { $0.date > $1.date }
        for historicalScore in history {
            let day = calendar.startOfDay(for: historicalScore.date)
            if seenDays.insert(day).inserted {
                scores.append(historicalScore)
            }
        }
        return scores
    }

    private var evidence: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm, alignment: .leading), count: dynamicTypeSize >= .xxLarge ? 1 : 2),
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(Array(trendBadges.prefix(2).enumerated()), id: \.offset) { _, detail in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(detail.label)
                        .foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Text(detail.value.formattedWithSeparator(fractionDigits: detail.fractionDigits))
                        .monospacedDigit()
                        .foregroundStyle(heroPositive)
                        .fixedSize()
                }
                .font(.caption2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(border, lineWidth: 0.5)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("dashboard-hero-baseline-\(detail.label)")
            }
        }
    }
}
