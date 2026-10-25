import SwiftUI
import Charts

/// Consolidated recovery & sleep card combining sleep deficit gauge with sleep-related insights.
/// Replaces the separate SleepDeficitBadgeView and sleep-category InsightCards.
struct RecoverySleepCard: View {
    let sleepDeficit: SleepDeficitAnalysis?
    let sleepInsights: [InsightCardData]
    let sleepMetric: HealthMetric?
    let onDismissInsight: (String) -> Void

    @ScaledMetric(relativeTo: .caption) private var historyHeight: CGFloat = 112
    @ScaledMetric(relativeTo: .caption) private var axisEdgePadding: CGFloat = DS.Spacing.sm
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if shouldShow {
            StandardCard(padding: DS.Spacing.xxl) {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
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
        hasValidSleep || hasValidDeficit || !sleepInsights.isEmpty
    }

    private var hasValidSleep: Bool {
        guard let metric = sleepMetric else { return false }
        return metric.value.isFinite && metric.value > 0
    }

    private var hasValidDeficit: Bool {
        guard let deficit = sleepDeficit else { return false }
        return deficit.level != .insufficient && deficit.weeklyDeficit.isFinite && deficit.weeklyDeficit >= 0
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "bed.double.fill")
                .font(.headline)
                .foregroundStyle(DS.Color.body)

            Text("Recovery & Sleep")
                .font(.headline)
        }
    }

    @ViewBuilder
    private var lastSleep: some View {
        if let metric = sleepMetric, hasValidSleep {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Last Sleep")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(metric.value.hoursMinutesFormatted)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dashboard-recovery-last-sleep-value")
                Text(metric.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Deficit Row

    @ViewBuilder
    private var deficitRow: some View {
        if let deficit = sleepDeficit, hasValidDeficit {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
            layout {
                Text("Sleep Debt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Text(deficit.weeklyDeficit.hoursMinutesFormatted)
                    .font(.headline)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Spacing.md)
            .background(DS.Color.sleep.opacity(DS.Opacity.subtle), in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .accessibilityIdentifier("dashboard-recovery-sleep-debt")
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
            if samples.count >= 2 {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text("Sleep History (hours)")
                            Spacer()
                            historyRange(samples)
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Sleep History (hours)")
                            historyRange(samples)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Chart(samples, id: \.date) { sample in
                        BarMark(
                            x: .value("Date", sample.date, unit: .day),
                            y: .value("Hours", sample.actualMinutes / 60)
                        )
                        .foregroundStyle(DS.Color.sleep)
                        .cornerRadius(3)
                    }
                    .chartYScale(range: .plotDimension(padding: axisEdgePadding))
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
                    if deficit.dailyDeficits.contains(where: { !$0.actualMinutes.isFinite || $0.actualMinutes <= 0 }) {
                        Text("Days without records are left blank.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func historyRange(_ samples: [SleepDeficitAnalysis.DailyDeficit]) -> some View {
        Group {
            if let first = samples.first, let last = samples.last {
                Text("\(first.date.formatted(.dateTime.month(.abbreviated).day())) – \(last.date.formatted(.dateTime.month(.abbreviated).day()))")
            }
        }
    }

    @ViewBuilder
    private var insightRows: some View {
        if !sleepInsights.isEmpty {
            if hasValidDeficit {
                Divider()
            }

            VStack(spacing: DS.Spacing.md) {
                ForEach(sleepInsights.prefix(2)) { card in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: card.iconName)
                            .font(.subheadline)
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
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Detail Link

    @ViewBuilder
    private var detailLink: some View {
        if let metric = sleepMetric, hasValidSleep {
            Divider()

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
            .accessibilityIdentifier("dashboard-recovery-sleep-details")
        }
    }
}

#Preview {
    RecoverySleepCard(
        sleepDeficit: nil,
        sleepInsights: [],
        sleepMetric: nil,
        onDismissInsight: { _ in }
    )
    .padding()
}
