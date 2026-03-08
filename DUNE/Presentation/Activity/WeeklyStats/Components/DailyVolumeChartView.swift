import SwiftUI
import Charts

/// Daily volume bar chart showing duration/calories per day within the selected period.
struct DailyVolumeChartView: View {
    let dailyBreakdown: [DailyVolumePoint]
    let period: VolumePeriod

    enum Metric: CaseIterable, Identifiable {
        case duration
        case sessions

        var id: Self { self }

        var displayName: String {
            Self.displayNames[self] ?? ""
        }

        private static let displayNames: [Metric: String] = [
            .duration: String(localized: "Duration"),
            .sessions: String(localized: "Sessions"),
        ]
    }

    @Environment(\.appTheme) private var theme

    @State private var selectedMetric: Metric = .duration
    @State private var selectedDate: Date?
    @State private var scrollPosition: Date = .now
    @State private var selectionGestureState = ChartSelectionGestureState()
    @State private var lastSelectionProbeLabel = "none"

    private enum Gradients {
        static let bar = LinearGradient(
            colors: [DS.Color.activity, DS.Color.activity.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Breakdown")
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
                                .accessibilityIdentifier("weeklystats-chart-visible-range")
                        }
                    }
                }
                Spacer()
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(Metric.allCases) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }

            if dailyBreakdown.isEmpty {
                Text("No workout data for this period.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                chartView
                    .frame(height: 160)
                    .clipped()
                    .overlay { chartAccessibilitySurface }
                    .id(selectedMetric)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: selectedMetric)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .onAppear(perform: resetScrollPosition)
        .onChange(of: dailyBreakdown.count) { _, _ in resetScrollPosition() }
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart(dailyBreakdown) { point in
            BarMark(
                x: .value("Date", point.date, unit: .day),
                y: .value(selectedMetric.displayName, valueFor(point))
            )
            .foregroundStyle(Gradients.bar)
            .cornerRadius(4)

            if point.id == selectedPoint?.id {
                RuleMark(x: .value("Date", point.date, unit: .day))
                    .foregroundStyle(theme.accentColor.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: period.chartAxisStrideCount)) { _ in
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
                AxisValueLabel(format: axisFormat, centered: true)
                    .foregroundStyle(theme.sandColor)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .foregroundStyle(theme.sandColor)
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
            }
        }
        .chartYScale(domain: 0...(maxY * 1.15))
        .chartXScale(domain: xDomain)
        .scrollableChartSelectionOverlay(
            isScrollable: isScrollable,
            visibleDomainLength: isScrollable ? period.visibleDomainSeconds : nil,
            scrollPosition: isScrollable ? $scrollPosition : nil,
            selectedDate: $selectedDate,
            selectionState: $selectionGestureState
        ) { proxy, plotFrame, chartSize in
            if let point = selectedPoint,
               let anchor = selectedAnchor(for: point, proxy: proxy, plotFrame: plotFrame) {
                FloatingChartSelectionOverlay(
                    date: point.date,
                    value: formattedValue(point),
                    anchor: anchor,
                    chartSize: chartSize,
                    plotFrame: plotFrame
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

    // MARK: - Helpers

    private var selectedPoint: DailyVolumePoint? {
        guard let selectedDate else { return nil }
        return ChartSelectionInteraction.nearestPoint(to: selectedDate, in: dailyBreakdown, date: \.date)
    }

    private var xDomain: ClosedRange<Date> {
        resolvedXDomain(scrollDomain: nil, dates: dailyBreakdown.map(\.date))
    }

    private var isScrollable: Bool {
        dailyBreakdown.count > period.days
    }

    private var chartAccessibilitySurface: some View {
        ChartUITestSurface(
            identifier: "weeklystats-chart-daily-volume",
            label: "Daily Breakdown Chart",
            value: isScrollable ? visibleRangeLabel : ""
        )
    }

    private var visibleRangeLabel: String {
        period.visibleRangeLabel(from: scrollPosition)
    }

    private var axisFormat: Date.FormatStyle {
        period == .week
            ? .dateTime.weekday(.abbreviated)
            : .dateTime.month(.abbreviated).day()
    }

    private func selectedAnchor(
        for point: DailyVolumePoint,
        proxy: ChartProxy,
        plotFrame: CGRect
    ) -> CGPoint? {
        ChartSelectionInteraction.anchor(
            xPosition: proxy.position(forX: point.date),
            yPosition: proxy.position(forY: valueFor(point)),
            plotFrame: plotFrame
        )
    }

    private func valueFor(_ point: DailyVolumePoint) -> Double {
        switch selectedMetric {
        case .duration: point.totalDuration / 60.0
        case .sessions: Double(point.segments.count)
        }
    }

    private var maxY: Double {
        let values = dailyBreakdown.map { valueFor($0) }
        return Swift.max(values.max() ?? 1, 1)
    }

    private func formattedValue(_ point: DailyVolumePoint) -> String {
        switch selectedMetric {
        case .duration:
            let mins = Int(point.totalDuration / 60.0)
            return "\(mins.formattedWithSeparator) min"
        case .sessions:
            return "\(point.segments.count) sessions"
        }
    }

    private func resetScrollPosition() {
        guard let latestDate = dailyBreakdown.map(\.date).max() else { return }
        let preferredStart = period.initialVisibleStart(latestDate: latestDate)
        scrollPosition = preferredStart < xDomain.lowerBound ? xDomain.lowerBound : preferredStart
    }

}
