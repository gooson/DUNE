import SwiftUI
import Charts

/// Consolidated recovery & sleep card combining sleep deficit gauge with sleep-related insights.
/// Replaces the separate SleepDeficitBadgeView and sleep-category InsightCards.
struct RecoverySleepCard: View {
    let sleepDeficit: SleepDeficitAnalysis?
    let sleepInsights: [InsightCardData]
    let sleepMetric: HealthMetric?
    var sleepStages: [SleepStage] = []
    let onDismissInsight: (String) -> Void

    @ScaledMetric(relativeTo: .caption) private var historyHeight: CGFloat = 112
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var validStages: [SleepStage] {
        sleepStages.filter { $0.endDate > $0.startDate && $0.duration.isFinite && $0.duration > 0 }
            .sorted { $0.startDate < $1.startDate } // oldest-first
    }

    var body: some View {
        if shouldShow {
            DashboardSupportCard {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    header
                    lastSleep
                    deficitRow
                    sleepHistory
                    insightRows
                    detailLink
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("dashboard-recovery-sleep-card")
        }
    }

    private var shouldShow: Bool {
        sleepMetric != nil || hasValidDeficit || !sleepInsights.isEmpty
    }

    private var hasValidDeficit: Bool {
        guard let deficit = sleepDeficit else { return false }
        return deficit.level != .insufficient
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "bed.double.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.body)
                .frame(width: 38, height: 38)
                .background(DS.Color.sleep.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

            Text("Recovery & Sleep")
                .font(.headline)
        }
    }

    @ViewBuilder
    private var lastSleep: some View {
        if let metric = sleepMetric {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Last Sleep").foregroundStyle(.secondary)
                        Text(metric.value.hoursMinutesFormatted).font(.title3.bold()).monospacedDigit()
                    }
                } else {
                    HStack {
                        Text("Last Sleep").foregroundStyle(.secondary)
                        Spacer()
                        Text(metric.value.hoursMinutesFormatted).font(.title3.bold()).monospacedDigit()
                    }
                }
                Text(metric.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let first = validStages.first, let end = validStages.map(\.endDate).max() {
                    Chart(Array(validStages.enumerated()), id: \.offset) { _, stage in
                        BarMark(
                            xStart: .value("Start", stage.startDate),
                            xEnd: .value("End", stage.endDate),
                            y: .value("Stage", "sleep")
                        )
                        .foregroundStyle(stage.stage.color)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartXScale(domain: first.startDate...end)
                    .frame(height: 30)
                    .clipped()
                    .accessibilityLabel("Sleep stages timeline, \(validStages.count) stages")

                    HStack {
                        Label {
                            Text(first.startDate, format: .dateTime.hour().minute())
                        } icon: { Image(systemName: "moon.fill") }
                        Spacer()
                        Label {
                            Text(end, format: .dateTime.hour().minute())
                        } icon: { Image(systemName: "sunrise.fill") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("dashboard-recovery-last-sleep")
        }
    }

    // MARK: - Deficit Row

    @ViewBuilder
    private var deficitRow: some View {
        if let deficit = sleepDeficit, hasValidDeficit {
            let levelColor = deficit.level.color
            HStack(spacing: DS.Spacing.md) {
                // Mini ring gauge
                ZStack {
                    Circle()
                        .stroke(levelColor.opacity(DS.Opacity.border), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(deficit.weeklyDeficit / 600.0, 1.0))
                        .stroke(levelColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Weekly Sleep Deficit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(deficit.formattedWeeklyDeficit)
                            .font(.subheadline.bold().monospacedDigit())

                        Text(deficit.level.label)
                            .font(.caption2)
                            .foregroundStyle(levelColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(levelColor.opacity(0.12), in: Capsule())
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Sleep Insights

    @ViewBuilder
    private var sleepHistory: some View {
        if let deficit = sleepDeficit, hasValidDeficit {
            let samples = Array(deficit.dailyDeficits
                .filter { $0.actualMinutes.isFinite && $0.actualMinutes > 0 }
                .sorted { $0.date < $1.date }
                    .suffix(7))
            if samples.count >= 2, let first = samples.first, let last = samples.last {
                let upperBound = max(4, ceil((samples.map { $0.actualMinutes / 60 }.max() ?? 0) / 2) * 2 + 2)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Sleep History")
                        .font(.caption.weight(.semibold))
                    HStack(spacing: DS.Spacing.xxs) {
                        Text(first.date, format: .dateTime.month(.abbreviated).day())
                        Text("–")
                        Text(last.date, format: .dateTime.month(.abbreviated).day())
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("dashboard-recovery-sleep-period")
                    Chart(samples, id: \.date) { sample in
                        BarMark(
                            x: .value("Date", sample.date, unit: .day),
                            y: .value("Hours", sample.actualMinutes / 60)
                        )
                        .foregroundStyle(DS.Color.sleep)
                        .cornerRadius(3)
                    }
                    .chartYScale(domain: 0...upperBound, range: .plotDimension(padding: 8))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                    }
                    .frame(height: historyHeight)
                    .padding(.top, DS.Spacing.xs)
                    .clipped()
                    .accessibilityIdentifier("dashboard-recovery-sleep-chart")
                }
            }
        }
    }

    @ViewBuilder
    private var insightRows: some View {
        if !sleepInsights.isEmpty {
            if hasValidDeficit {
                Divider().opacity(0.3)
            }

            VStack(spacing: DS.Spacing.xs) {
                ForEach(sleepInsights.prefix(2)) { card in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: card.iconName)
                            .font(.caption)
                            .foregroundStyle(card.category.iconColor)
                            .frame(width: 20)

                        Text(card.message)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        Button {
                            onDismissInsight(card.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss sleep insight")
                    }
                }
            }
        }
    }

    // MARK: - Detail Link

    @ViewBuilder
    private var detailLink: some View {
        if let metric = sleepMetric {
            Divider().opacity(0.3)

            NavigationLink(value: metric) {
                HStack {
                    Text("Sleep Details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
