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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let score {
            themeSleepSummary(score: score)
        } else {
            emptyCard
        }
    }

    private func themeSleepSummary(score: WellnessScore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink(value: WellnessScoreDestination()) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Wellness")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.directionPreviewTextColor)
                        Spacer()
                        Text("Sleep")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.directionPreviewTextColor.opacity(0.74))
                    }

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

                    Text(score.narrativeMessage)
                        .font(.subheadline)
                        .foregroundStyle(theme.directionPreviewTextColor.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("wellness-hero-narrative")

                    HStack(alignment: .center, spacing: 18) {
                        Group {
                            if sleepTrend.contains(where: { $0.minutes > 0 }) {
                                HStack(alignment: .bottom, spacing: 5) {
                                    ForEach(Array(sleepTrend.suffix(7).enumerated()), id: \.offset) { index, sample in
                                        if sample.minutes > 0 {
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill((theme == .desertWarm
                                                    ? Color(red: 0.350, green: 0.690, blue: 0.588)
                                                    : theme.metricSleep).opacity(index == sleepTrend.suffix(7).count - 1 ? 1 : 0.55))
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
                                    .foregroundStyle(theme.directionPreviewTextColor.opacity(0.74))
                                    .accessibilityIdentifier("wellness-sleep-empty-state")
                            }
                        }
                        .frame(minWidth: 88, minHeight: 62, alignment: .bottomLeading)

                        VStack(alignment: .leading, spacing: 5) {
                            if let minutes = sleepTrend.last?.minutes, minutes > 0 {
                                Text("\(Int(minutes) / 60)h \(Int(minutes) % 60)min")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(theme.directionPreviewTextColor)
                            } else {
                                Text("Need More Data")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(theme.directionPreviewTextColor)
                            }
                            Text("Sleep")
                                .font(.subheadline)
                                .foregroundStyle(theme.directionPreviewTextColor.opacity(0.74))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wellness-hero-score")
            .accessibilityLabel("Wellness score \(score.score), \(score.status.label)")

            if let sleepMetric {
                NavigationLink(value: sleepMetric) {
                    HStack(spacing: 6) {
                        Text("Sleep Details")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme == .desertWarm
                        ? (colorScheme == .dark
                            ? Color(red: 0.898, green: 0.678, blue: 0.514)
                            : Color(red: 0.588, green: 0.349, blue: 0.220))
                        : theme.directionPreviewActionColor(for: colorScheme))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wellness-sleep-detail-link")
            } else {
                NavigationLink(value: WellnessScoreDestination()) {
                    HStack(spacing: 6) {
                        Text("View Details")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme == .desertWarm
                        ? (colorScheme == .dark
                            ? Color(red: 0.898, green: 0.678, blue: 0.514)
                            : Color(red: 0.588, green: 0.349, blue: 0.220))
                        : theme.directionPreviewActionColor(for: colorScheme))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wellness-score-detail-link")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 23)
                .fill(theme == .desertWarm
                    ? LinearGradient(colors: [colorScheme == .dark ? Color(red: 0.110, green: 0.120, blue: 0.125) : Color(red: 0.988, green: 0.969, blue: 0.937)], startPoint: .top, endPoint: .bottom)
                    : theme.directionPreviewBackground)
                .overlay(alignment: .bottom) {
                    if theme == .desertWarm {
                        DesertPreviewWave()
                            .frame(height: 74)
                            .clipped()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 23))
                .overlay {
                    RoundedRectangle(cornerRadius: 23)
                        .strokeBorder(theme == .desertWarm
                            ? (colorScheme == .dark
                                ? Color(red: 0.251, green: 0.314, blue: 0.286)
                                : Color(red: 0.871, green: 0.859, blue: 0.824))
                            : theme.accentColor.opacity(0.25), lineWidth: 1)
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
            .foregroundStyle(theme.directionPreviewTextColor)
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
