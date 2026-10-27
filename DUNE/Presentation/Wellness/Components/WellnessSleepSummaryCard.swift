import SwiftUI

struct WellnessSleepSummaryCard: View {
    let sleepTrend: [SleepDailySample]
    let sleepMetric: HealthMetric?

    @Environment(\.appTheme) private var theme

    private var ink: Color { theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor }
    private var muted: Color { theme == .desertWarm ? DesertPalette.muted : theme.directionPreviewTextColor.opacity(0.74) }

    // Date filtering is based on recorded days, never on array positions or fabricated gaps.
    private var recentSamples: [SleepDailySample] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let firstDay = calendar.date(byAdding: .day, value: -6, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        return sleepTrend
            .filter { sample in
                sample.minutes.isFinite && sample.minutes > 0 &&
                sample.date >= firstDay && sample.date < tomorrow
            }
            .sorted { $0.date < $1.date }
    }

    private var latest: SleepDailySample? { recentSamples.last }

    private var meanMinutes: Int? {
        guard recentSamples.count >= 2 else { return nil }
        return Int((recentSamples.reduce(0) { $0 + $1.minutes } / Double(recentSamples.count)).rounded())
    }

    private func duration(_ minutes: Int) -> String {
        String(localized: "\(minutes / 60)h \(minutes % 60)min")
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if let sleepMetric {
                    NavigationLink(value: sleepMetric) { content(showsChevron: true) }
                        .buttonStyle(CardNavigationButtonStyle())
                        .accessibilityIdentifier("wellness-hero-sleep")
                } else {
                    content(showsChevron: false)
                }
            }
        }
        .accessibilityIdentifier("wellness-sleep-summary-card")
    }

    private func content(showsChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            CardNavigationHeader(showsChevron: showsChevron, chevronColor: ink) {
                Text("Recent Sleep")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(ink)
            }
            if let latest {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(duration(Int(latest.minutes.rounded())))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(ink)
                        .accessibilityIdentifier("wellness-sleep-latest")
                    Text(latest.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption).foregroundStyle(muted)
                    if let meanMinutes {
                        Text("7-day average · \(duration(meanMinutes))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(muted)
                            .accessibilityIdentifier("wellness-sleep-average")
                    }
                }
                if recentSamples.count >= 2 {
                    HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                        ForEach(Array(recentSamples.enumerated()), id: \.offset) { _, sample in
                            VStack(spacing: DS.Spacing.xs) {
                                Capsule()
                                    .fill(DS.Color.sleep.opacity(sample.date == latest.date ? 1 : 0.6))
                                    .frame(height: max(8, min(54, CGFloat(sample.minutes / 600 * 54))))
                                    .frame(maxHeight: 54, alignment: .bottom)
                                Text(sample.date.formatted(.dateTime.day()))
                                    .font(.caption2).foregroundStyle(muted)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("\(sample.date.formatted(.dateTime.month(.abbreviated).day())), \(duration(Int(sample.minutes.rounded())))")
                        }
                    }
                    .frame(height: 70, alignment: .bottom)
                    .accessibilityIdentifier("wellness-sleep-observed-bars")
                }
            } else {
                Text("Need More Data")
                    .font(.subheadline).foregroundStyle(muted)
                    .accessibilityIdentifier("wellness-sleep-empty-state")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        WellnessSleepSummaryCard(sleepTrend: [], sleepMetric: nil).padding()
    }
}
