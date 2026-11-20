import SwiftUI

struct WellnessSleepSummaryCard: View {
    let sleepTrend: [SleepDailySample]
    let sleepMetric: HealthMetric?

    @State private var selectedDay: Date?
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
        let valid = sleepTrend.filter { sample in
            sample.minutes.isFinite && sample.minutes > 0 && sample.minutes <= 1440 &&
            sample.date >= firstDay && sample.date < tomorrow
        }
        return Dictionary(grouping: valid) { calendar.startOfDay(for: $0.date) }
            .compactMap { $0.value.max { $0.date < $1.date } }
            .sorted { $0.date < $1.date }
    }

    private var latest: SleepDailySample? { recentSamples.last }

    private var selectedSample: SleepDailySample? {
        guard let selectedDay else { return latest }
        return recentSamples.last { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
    }

    private var recentDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private var figuresLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.xs))
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
                    NavigationLink(value: sleepMetric) { header(showsChevron: true) }
                        .buttonStyle(CardNavigationButtonStyle())
                        .accessibilityIdentifier("wellness-hero-sleep")
                } else {
                    header(showsChevron: false)
                }
                content()
            }
        }
    }

    private func header(showsChevron: Bool) -> some View {
        CardNavigationHeader(showsChevron: showsChevron, chevronColor: ink) {
            Text("Recent Sleep")
                .accessibilityIdentifier("wellness-sleep-summary-card")
                .font(.headline.weight(.semibold))
                .foregroundStyle(ink)
        }
    }

    private func content() -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let latest {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(duration(Int(latest.minutes.rounded())))
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                        .foregroundStyle(ink)
                        .accessibilityIdentifier("wellness-sleep-latest")
                    Text(latest.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption).foregroundStyle(muted)
                    figuresLayout {
                        if let meanMinutes {
                            Text("7-day average · \(duration(meanMinutes))")
                                .font(.title2.weight(.semibold).monospacedDigit())
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(muted)
                                .accessibilityIdentifier("wellness-sleep-average")
                        }
                        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                        Text("Recorded \(recentSamples.count) of 7 nights")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(muted)
                        .accessibilityIdentifier("wellness-sleep-observation-count")
                    }
                    if let selectedDay {
                        if let selectedSample {
                            HStack(spacing: DS.Spacing.xs) {
                                Text(selectedDay.formatted(.dateTime.month(.abbreviated).day()))
                                Text(duration(Int(selectedSample.minutes.rounded())))
                            }
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .accessibilityIdentifier("wellness-sleep-selected-value")
                        } else {
                            HStack(spacing: DS.Spacing.xs) {
                                Text(selectedDay.formatted(.dateTime.month(.abbreviated).day()))
                                Text("No record")
                            }
                            .font(.subheadline)
                            .accessibilityIdentifier("wellness-sleep-selected-empty")
                        }
                    }
                }
                observedBars(latest: latest)
            } else {
                Text("Need More Data")
                    .font(.subheadline).foregroundStyle(muted)
                    .accessibilityIdentifier("wellness-sleep-empty-state")
                Text("Recorded \(0) of 7 nights")
                .font(.caption)
                .foregroundStyle(muted)
                .accessibilityIdentifier("wellness-sleep-observation-count")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func dayAccessibilityLabel(day: Date, sample: SleepDailySample?) -> Text {
        let date = Text(day, format: .dateTime.month(.abbreviated).day())
        if let sample {
            return date + Text(verbatim: ", ") + Text(duration(Int(sample.minutes.rounded())))
        }
        return date + Text(verbatim: ", ") + Text("No record")
    }

    private func observedBars(latest: SleepDailySample) -> some View {
        let samples = recentSamples
        let scale = barScaleMinutes
        let days = recentDays
        return VStack(spacing: DS.Spacing.sm) {
            HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let sample = samples.last { Calendar.current.isDate($0.date, inSameDayAs: day) }
                    Button {
                        selectedDay = day
                    } label: {
                        ZStack(alignment: .bottom) {
                            Color.clear
                            if let sample {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DS.Color.sleep.opacity(Calendar.current.isDate(sample.date, inSameDayAs: selectedDay ?? latest.date) ? 1 : 0.6))
                                    .frame(width: 16, height: max(4, CGFloat(sample.minutes / scale * 64)))
                                    .accessibilityIdentifier("wellness-sleep-bar-\(index)")
                            }
                        }
                        .frame(height: 64)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(dayAccessibilityLabel(day: day, sample: sample))
                    .accessibilityIdentifier("wellness-sleep-day-\(index)")
                }
            }
            HStack(spacing: DS.Spacing.xs) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    if !dynamicTypeSize.isAccessibilitySize || index.isMultiple(of: 3) {
                        if dynamicTypeSize.isAccessibilitySize, index > 0 { Spacer(minLength: 0) }
                        Text(day.formatted(.dateTime.day()))
                            .font(.caption2).foregroundStyle(muted)
                            .fixedSize()
                            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? nil : .infinity)
                            .accessibilityIdentifier("wellness-sleep-date-\(index)")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WellnessSleepSummaryCard(sleepTrend: [], sleepMetric: nil).padding()
    }
}
