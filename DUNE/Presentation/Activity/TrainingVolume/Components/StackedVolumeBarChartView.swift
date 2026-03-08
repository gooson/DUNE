import SwiftUI
import Charts

/// Stacked bar chart showing daily exercise volume breakdown by type.
struct StackedVolumeBarChartView: View {
    let dailyBreakdown: [DailyVolumePoint]
    let topTypeKeys: [String] // Top 5 type keys for color assignment
    let typeColors: [String: Color]
    let typeNames: [String: String]
    let period: VolumePeriod

    @Environment(\.appTheme) private var theme

    @State private var selectedDate: Date?
    @State private var scrollPosition: Date = .now
    @State private var selectionGestureState = ChartSelectionGestureState()
    @State private var lastSelectionProbeLabel = "none"

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Volume")
                    .font(.subheadline.weight(.semibold))

                if isScrollable {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(visibleRangeLabel)
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textSecondary)
                            .contentTransition(.numericText())

                        Color.clear
                            .frame(width: 1, height: 1)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(visibleRangeLabel)
                            .accessibilityIdentifier("training-volume-daily-volume-visible-range")
                    }
                }
            }

            if dailyBreakdown.isEmpty || dailyBreakdown.allSatisfy({ $0.segments.isEmpty }) {
                emptyState
            } else {
                chartView
                    .frame(height: 160)
                    .clipped()
                    .overlay { chartAccessibilitySurface }

                legendRow
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .onAppear(perform: resetScrollPosition)
        .onChange(of: dailyBreakdown.count) { _, _ in resetScrollPosition() }
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart {
            ForEach(dailyBreakdown) { day in
                ForEach(flattenedSegments(for: day), id: \.id) { segment in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Minutes", segment.minutes)
                    )
                    .foregroundStyle(colorFor(segment.typeKey))
                }
            }

            if let day = selectedPoint {
                RuleMark(x: .value("Selected", day.date, unit: .day))
                    .foregroundStyle(theme.accentColor.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: period.chartAxisStrideCount)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(theme.sandColor)
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let mins = value.as(Double.self) {
                    AxisValueLabel {
                        Text(
                            mins >= 60
                            ? "\((mins / 60).formattedWithSeparator())h"
                            : mins.formattedWithSeparator()
                        )
                        .foregroundStyle(theme.sandColor)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
            }
        }
        .chartYScale(domain: 0...(maxDailyMinutes * 1.15))
        .scrollableChartSelectionOverlay(
            isScrollable: isScrollable,
            visibleDomainLength: isScrollable ? period.visibleDomainSeconds : nil,
            scrollPosition: isScrollable ? $scrollPosition : nil,
            selectedDate: $selectedDate,
            selectionState: $selectionGestureState
        ) { proxy, plotFrame, chartSize in
            if let day = selectedPoint,
               let anchor = selectedAnchor(for: day, proxy: proxy, plotFrame: plotFrame) {
                let totalMins = day.totalDuration / 60.0
                FloatingChartSelectionOverlay(
                    date: day.date,
                    value: totalMins >= 60
                        ? "\((totalMins / 60).formattedWithSeparator(fractionDigits: 1))h"
                        : "\(totalMins.formattedWithSeparator())m",
                    anchor: anchor,
                    chartSize: chartSize,
                    plotFrame: plotFrame,
                    dateFormat: .dateTime.month(.abbreviated).day()
                )
                .transition(.opacity)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedPoint?.date)
        .onChange(of: selectedPoint?.date) { _, newValue in
            guard let newValue else { return }
            lastSelectionProbeLabel = newValue.formatted(date: .abbreviated, time: .omitted)
        }
        .chartSelectionUITestProbe(lastSelectionProbeLabel)
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(topTypeKeys.prefix(5), id: \.self) { key in
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorFor(key))
                        .frame(width: 6, height: 6)
                    Text(typeNames[key] ?? key)
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Helpers

    private struct FlatSegment: Identifiable {
        let id: String
        let typeKey: String
        let minutes: Double
    }

    private func flattenedSegments(for day: DailyVolumePoint) -> [FlatSegment] {
        day.segments.map { segment in
            FlatSegment(
                id: "\(day.date.timeIntervalSince1970)-\(segment.typeKey)",
                typeKey: segment.typeKey,
                minutes: segment.duration / 60.0
            )
        }
    }

    private func colorFor(_ typeKey: String) -> Color {
        typeColors[typeKey] ?? .gray.opacity(0.5)
    }

    private var selectedPoint: DailyVolumePoint? {
        guard let selectedDate else { return nil }
        return ChartSelectionInteraction.nearestPoint(to: selectedDate, in: dailyBreakdown, date: \.date)
    }

    private var xDomain: ClosedRange<Date> {
        resolvedDayBucketXDomain(dates: dailyBreakdown.map(\.date))
    }

    private var isScrollable: Bool {
        dailyBreakdown.count > period.days
    }

    private var visibleRangeLabel: String {
        period.visibleRangeLabel(from: scrollPosition)
    }

    private var chartAccessibilitySurface: some View {
        ChartUITestSurface(
            identifier: "training-volume-chart-daily-volume",
            label: String(localized: "Daily Volume"),
            value: isScrollable ? visibleRangeLabel : ""
        )
    }

    private func selectedAnchor(
        for point: DailyVolumePoint,
        proxy: ChartProxy,
        plotFrame: CGRect
    ) -> CGPoint? {
        ChartSelectionInteraction.anchor(
            xPosition: proxy.position(forX: point.date),
            yPosition: proxy.position(forY: point.totalDuration / 60.0),
            plotFrame: plotFrame
        )
    }

    private var maxDailyMinutes: Double {
        let maxVal = dailyBreakdown.map { $0.totalDuration / 60.0 }.max() ?? 0
        return Swift.max(maxVal, 1)
    }

    private func resetScrollPosition() {
        guard let latestDate = dailyBreakdown.map(\.date).max() else { return }
        let preferredStart = period.initialVisibleStart(latestDate: latestDate)
        scrollPosition = preferredStart < xDomain.lowerBound ? xDomain.lowerBound : preferredStart
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("Daily volume will appear as you exercise")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

}
