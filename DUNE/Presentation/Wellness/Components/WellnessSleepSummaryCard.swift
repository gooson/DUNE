import SwiftUI

struct WellnessSleepSummaryCard: View {
    let sleepTrend: [SleepDailySample]
    let sleepMetric: HealthMetric?

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    private var recentDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private var barScaleMinutes: Double {
        max(600, recentSamples.map(\.minutes).max() ?? 600)
    }

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
    }

    private func content(showsChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            CardNavigationHeader(showsChevron: showsChevron, chevronColor: ink) {
                Text("Recent Sleep")
                    .accessibilityIdentifier("wellness-sleep-summary-card")
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
                observedBars(latest: latest)
            } else {
                Text("Need More Data")
                    .font(.subheadline).foregroundStyle(muted)
                    .accessibilityIdentifier("wellness-sleep-empty-state")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func observedBars(latest: SleepDailySample) -> some View {
        let samples = recentSamples
        let scale = barScaleMinutes
        return HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
            ForEach(Array(recentDays.enumerated()), id: \.element) { index, day in
                let sample = samples.last { Calendar.current.isDate($0.date, inSameDayAs: day) }
                VStack(spacing: DS.Spacing.sm) {
                    ZStack(alignment: .bottom) {
                        Color.clear
                        if let sample {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DS.Color.sleep.opacity(sample.date == latest.date ? 1 : 0.6))
                                .frame(width: 16, height: max(4, CGFloat(sample.minutes / scale * 64)))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(sample.date.formatted(.dateTime.month(.abbreviated).day())), \(duration(Int(sample.minutes.rounded())))")
                                .accessibilityIdentifier("wellness-sleep-bar-\(index)")
                        }
                    }
                    .frame(height: 64)
                    Text(!dynamicTypeSize.isAccessibilitySize || index.isMultiple(of: 3)
                         ? day.formatted(.dateTime.day()) : " ")
                        .font(.caption2).foregroundStyle(muted)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WellnessSleepSummaryCard(sleepTrend: [], sleepMetric: nil).padding()
    }
}
