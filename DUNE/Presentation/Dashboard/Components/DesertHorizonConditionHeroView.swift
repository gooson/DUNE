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

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }
    private var isDesert: Bool { palette.isDesert }
    private var surface: Color { palette.surface }
    private var border: Color { palette.border }
    private var gold: Color { palette.gold }
    private var heroAccent: Color { palette.heroAccent }
    private var heroHighlight: Color { palette.heroHighlight }
    private var heroPositive: Color { palette.heroPositive }
    private var muted: Color { palette.muted }
    private var ink: Color { palette.ink }

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
        CardNavigationHeader(minimumHeight: 0, chevronColor: heroAccent) {
            Text(verbatim: "CONDITION")
                .accessibilityIdentifier("dashboard-hero-heading")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
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
            trackColor: palette.track,
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
