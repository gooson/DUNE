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

    private enum Labels {
        static let wellness = "WELLNESS"
        static let sleep = String(localized: "Sleep Score")
        static let condition = String(localized: "Condition")
        static let body = String(localized: "Body")
    }

    var body: some View {
        if let score {
            if theme == .desertWarm {
                desertSleepSummary(score: score)
            } else {
                standardHero(score: score)
            }
        } else {
            emptyCard
        }
    }

    private func standardHero(score: WellnessScore) -> some View {
        HeroScoreCard(
                score: score.score,
                scoreLabel: Labels.wellness,
                statusLabel: score.status.label,
                statusIcon: score.status.iconName,
                statusColor: score.status.color,
                guideMessage: score.narrativeMessage,
                subScores: [
                    .init(label: Labels.sleep, value: sleepScore, color: DS.Color.sleep),
                    .init(label: Labels.condition, value: conditionScore, color: DS.Color.hrv),
                    .init(label: Labels.body, value: bodyScore, color: DS.Color.body)
                ],
                badgeText: nil,
                showsChevron: true,
                accessibilityLabel: "Wellness score \(score.score), \(score.status.label)",
                accessibilityHint: "Tap to see score details",
                hourlySparkline: hourlySparkline,
                trendTitle: "Wellness Trend"
            )
    }

    private func desertSleepSummary(score: WellnessScore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink(value: WellnessScoreDestination()) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Wellness")
                            .font(.title3.weight(.bold))
                        Spacer()
                        Text("Sleep")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .center, spacing: 18) {
                        Group {
                            if sleepTrend.contains(where: { $0.minutes > 0 }) {
                                HStack(alignment: .bottom, spacing: 5) {
                                    ForEach(Array(sleepTrend.suffix(7).enumerated()), id: \.offset) { index, sample in
                                        if sample.minutes > 0 {
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(Color(red: 0.350, green: 0.690, blue: 0.588).opacity(index == sleepTrend.suffix(7).count - 1 ? 1 : 0.55))
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
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("wellness-sleep-empty-state")
                            }
                        }
                        .frame(minWidth: 88, minHeight: 62, alignment: .bottomLeading)

                        VStack(alignment: .leading, spacing: 5) {
                            if let minutes = sleepTrend.last?.minutes, minutes > 0 {
                                Text("\(Int(minutes) / 60)h \(Int(minutes) % 60)min")
                                    .font(.headline.weight(.semibold))
                            } else {
                                Text("Need More Data")
                                    .font(.headline.weight(.semibold))
                            }
                            Text(score.narrativeMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
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
                    .foregroundStyle(colorScheme == .dark
                        ? Color(red: 0.898, green: 0.678, blue: 0.514)
                        : Color(red: 0.588, green: 0.349, blue: 0.220))
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
                    .foregroundStyle(colorScheme == .dark
                        ? Color(red: 0.898, green: 0.678, blue: 0.514)
                        : Color(red: 0.588, green: 0.349, blue: 0.220))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wellness-score-detail-link")
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
