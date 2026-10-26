import SwiftUI

struct WellnessHeroCard: View {
    let score: WellnessScore?
    let sleepScore: Int?
    let conditionScore: Int?
    let bodyScore: Int?
    var hourlySparkline: HourlySparklineData?
    var sleepTrend: [SleepDailySample] = []
    var sleepMetric: HealthMetric?
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesSideBySideLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var recentSleepSamples: [SleepDailySample] {
        Array(sleepTrend.suffix(7))
    }

    private var validSleepSamples: [SleepDailySample] {
        recentSleepSamples.filter { $0.minutes > 0 }
    }

    private var latestSleepSample: SleepDailySample? {
        validSleepSamples.last
    }

    private var averageSleepMinutes: Int? {
        guard validSleepSamples.count >= 2 else { return nil }
        return Int((validSleepSamples.map(\.minutes).reduce(0, +) / Double(validSleepSamples.count)).rounded())
    }

    private func sleepDuration(_ minutes: Int) -> String {
        String(localized: "\(minutes / 60)h \(minutes % 60)min")
    }

    private var sleepAccessibilitySummary: String {
        guard let latestSleepSample else {
            return "\(String(localized: "Sleep")), \(String(localized: "Need More Data"))"
        }
        let latest = sleepDuration(Int(latestSleepSample.minutes))
        let date = latestSleepSample.date.formatted(.dateTime.month(.abbreviated).day())
        guard let averageSleepMinutes else {
            return "\(String(localized: "Sleep")) \(date), \(latest)"
        }
        return "\(String(localized: "Sleep")) \(date), \(latest). \(String(localized: "7d")) \(String(localized: "Average")) \(sleepDuration(averageSleepMinutes))"
    }

    var body: some View {
        if let score {
            themeSleepSummary(score: score)
        } else {
            emptyCard
        }
    }

    private func themeSleepSummary(score: WellnessScore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if usesSideBySideLayout {
                HStack(alignment: .top, spacing: 24) {
                    wellnessScoreLink(score)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    sleepSection
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                wellnessScoreLink(score)
                sleepSection
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if theme == .desertWarm {
                DesertCardSurface(cornerRadius: DS.Radius.xxl)
            } else {
                RoundedRectangle(cornerRadius: 23)
                    .fill(theme.directionPreviewBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 23)
                            .strokeBorder(theme.accentColor.opacity(0.25), lineWidth: 1)
                    }
            }
        }
    }

    private func wellnessScoreLink(_ score: WellnessScore) -> some View {
        NavigationLink(value: WellnessScoreDestination()) {
            VStack(alignment: .leading, spacing: 16) {
                CardNavigationHeader(
                    minimumHeight: 0,
                    chevronColor: theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor
                ) {
                    Text("Wellness")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor)
                }
                wellnessStatus(score)
                wellnessNarrative(score)
            }
            .frame(maxWidth: .infinity, maxHeight: usesSideBySideLayout ? .infinity : nil, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(CardNavigationButtonStyle())
        .accessibilityIdentifier("wellness-hero-score")
        .accessibilityLabel("Wellness score \(score.score), \(score.status.label)")
        .accessibilityHint("Wellness Details")
    }

    @ViewBuilder
    private var sleepSection: some View {
        if let sleepMetric {
            NavigationLink(value: sleepMetric) {
                sleepSectionContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(CardNavigationButtonStyle())
            .accessibilityIdentifier("wellness-hero-sleep")
            .accessibilityLabel(sleepAccessibilitySummary)
        } else {
            sleepSectionContent
        }
    }

    private var sleepSectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardNavigationHeader(
                showsChevron: sleepMetric != nil,
                minimumHeight: 0,
                chevronColor: theme == .desertWarm
                    ? DesertPalette.muted
                    : theme.directionPreviewTextColor.opacity(0.74)
            ) {
                Text("Sleep")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme == .desertWarm ? DesertPalette.muted : theme.directionPreviewTextColor.opacity(0.74))
            }
            sleepSummary
        }
        .frame(maxWidth: .infinity, maxHeight: usesSideBySideLayout ? .infinity : nil, alignment: .topLeading)
    }

    @ViewBuilder
    private func wellnessStatus(_ score: WellnessScore) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                wellnessRing(score)
                wellnessCopy(score)
            }
        } else {
            HStack(alignment: .center, spacing: 18) {
                wellnessRing(score)
                wellnessCopy(score)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func wellnessNarrative(_ score: WellnessScore) -> some View {
        Text(score.narrativeMessage)
            .font(.subheadline)
            .foregroundStyle(theme == .desertWarm ? DesertPalette.muted : theme.directionPreviewTextColor.opacity(0.74))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("wellness-hero-narrative")
    }

    @ViewBuilder
    private var sleepSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                sleepBars
                sleepCopy
            }
        } else {
            HStack(alignment: .center, spacing: 18) {
                sleepBars
                sleepCopy
            }
        }
    }

    private var sleepBars: some View {
        Group {
            if !validSleepSamples.isEmpty {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(recentSleepSamples.enumerated()), id: \.offset) { _, sample in
                        if sample.minutes > 0 {
                            RoundedRectangle(cornerRadius: 5)
                                .fill((theme == .desertWarm
                                    ? Color(red: 0.350, green: 0.690, blue: 0.588)
                                    : theme.metricSleep).opacity(sample.date == latestSleepSample?.date ? 1 : 0.55))
                                .frame(width: 12, height: max(9, min(60, CGFloat(sample.minutes / 600) * 60)))
                        } else {
                            Color.clear.frame(width: 12, height: 0)
                        }
                    }
                }
                .accessibilityLabel("Sleep")
            } else {
                Text("Need More Data")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme == .desertWarm ? DesertPalette.muted : theme.directionPreviewTextColor.opacity(0.74))
                    .accessibilityIdentifier("wellness-sleep-empty-state")
            }
        }
        .frame(minWidth: 88, minHeight: 62, alignment: .bottomLeading)
    }

    private var sleepCopy: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let latestSleepSample {
                Text(sleepDuration(Int(latestSleepSample.minutes)))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor)
                    .accessibilityIdentifier("wellness-sleep-latest")
                Text(latestSleepSample.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(theme == .desertWarm ? DesertPalette.muted : theme.directionPreviewTextColor.opacity(0.74))
            } else {
                Text("Need More Data")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor)
            }
            Text("Sleep")
                .font(.subheadline)
                .foregroundStyle(theme == .desertWarm ? DesertPalette.muted : theme.directionPreviewTextColor.opacity(0.74))
            if let averageSleepMinutes {
                Text("7d Average · \(sleepDuration(averageSleepMinutes))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme == .desertWarm ? DesertPalette.muted : theme.directionPreviewTextColor.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("wellness-sleep-average")
            }
        }
    }

    private func wellnessRing(_ score: WellnessScore) -> some View {
        TabHeroScoreRing(
            progress: Double(score.score) / 100,
            value: score.score.formatted(),
            caption: "WELLNESS",
            tipColor: score.status.color,
            accessibilityLabel: "Wellness score \(score.score), \(score.status.label)",
            accessibilityIdentifier: "wellness-hero-ring"
        )
    }

    private func wellnessCopy(_ score: WellnessScore) -> some View {
        Text(score.status.label)
            .font(.headline.weight(.semibold))
            .foregroundStyle(theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor)
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
                    .foregroundStyle(DS.Color.textSecondary)

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
