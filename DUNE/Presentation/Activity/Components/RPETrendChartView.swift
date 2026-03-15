import SwiftUI
import Charts

/// 28-day RPE trend bar chart shown on the Training Volume detail screen.
/// Each bar represents daily average RPE, color-coded by intensity zone.
struct RPETrendChartView: View {
    let data: [RPETrendDataPoint]
    let period: VolumePeriod

    @Environment(\.appTheme) private var theme

    @State private var selectedDate: Date?
    @State private var scrollPosition: Date = .now
    @State private var cachedMovingAverage: [ChartDataPoint] = []
    @State private var selectionGestureState = ChartSelectionGestureState()
    @State private var lastSelectionProbeLabel = "none"

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("RPE Trend", systemImage: "gauge.with.dots.needle.67percent")
                        .font(.subheadline.weight(.semibold))

                    if isScrollable {
                        Text(visibleRangeLabel)
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textSecondary)
                            .contentTransition(.numericText())
                    }
                }
                Spacer()
                if let avg = weekAverageRPE {
                    Text(avg)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            chartView
                .frame(height: 140)
                .clipped()
                .overlay { chartAccessibilitySurface }

            // Legend
            HStack(spacing: DS.Spacing.md) {
                legendItem(color: DS.Color.positive, label: "Light")
                legendItem(color: DS.Color.caution, label: "Moderate")
                legendItem(color: DS.Color.scoreTired, label: "Hard")
                legendItem(color: DS.Color.negative, label: "Max")
            }
            .font(.caption2)
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .onAppear {
            recalculateMovingAverage()
            resetScrollPosition()
        }
        .onChange(of: data.count) { _, _ in
            recalculateMovingAverage()
            resetScrollPosition()
        }
    }

    private func recalculateMovingAverage() {
        cachedMovingAverage = computeMovingAverage()
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart {
            ForEach(data) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("RPE", point.averageRPE)
                )
                .foregroundStyle(barColor(for: point.averageRPE))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            if cachedMovingAverage.count >= 2 {
                ForEach(cachedMovingAverage) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Average", point.value),
                        series: .value("Series", "avg")
                    )
                    .foregroundStyle(DS.Color.activity.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }

            if let point = selectedPoint {
                RuleMark(x: .value("Selected", point.date, unit: .day))
                    .foregroundStyle(theme.accentColor.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: period.chartAxisStrideCount)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(theme.sandColor)
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10]) { _ in
                AxisValueLabel()
                    .foregroundStyle(theme.sandColor)
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
            }
        }
        .chartYScale(domain: 0...10)
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
                    value: String(format: "%.1f", point.averageRPE),
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

    // MARK: - Helpers

    private func barColor(for rpe: Double) -> Color {
        switch rpe {
        case ..<5:   DS.Color.positive
        case 5..<7:  DS.Color.caution
        case 7..<9:  DS.Color.scoreTired
        default:     DS.Color.negative
        }
    }

    private func legendItem(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundStyle(DS.Color.textSecondary)
        }
    }

    private var xDomain: ClosedRange<Date> {
        resolvedDayBucketXDomain(dates: data.map(\.date))
    }

    private var isScrollable: Bool {
        data.count > period.days
    }

    private var chartAccessibilitySurface: some View {
        ChartUITestSurface(
            identifier: "rpe-trend-chart",
            label: "RPE Trend Chart",
            value: isScrollable ? visibleRangeLabel : ""
        )
    }

    private var visibleRangeLabel: String {
        period.visibleRangeLabel(from: scrollPosition)
    }

    private var selectedPoint: RPETrendDataPoint? {
        guard let selectedDate else { return nil }
        return ChartSelectionInteraction.nearestPoint(to: selectedDate, in: data, date: \.date)
    }

    private func selectedAnchor(
        for point: RPETrendDataPoint,
        proxy: ChartProxy,
        plotFrame: CGRect
    ) -> CGPoint? {
        ChartSelectionInteraction.anchor(
            xPosition: proxy.position(forX: point.date),
            yPosition: proxy.position(forY: point.averageRPE),
            plotFrame: plotFrame
        )
    }

    private func resetScrollPosition() {
        guard let latestDate = data.map(\.date).max() else { return }
        let preferredStart = period.initialVisibleStart(latestDate: latestDate)
        scrollPosition = preferredStart < xDomain.lowerBound ? xDomain.lowerBound : preferredStart
    }

    /// 7-day rolling average
    private func computeMovingAverage() -> [ChartDataPoint] {
        guard data.count >= 7 else { return [] }
        var result: [ChartDataPoint] = []
        for i in 6..<data.count {
            let window = data[(i - 6)...i]
            let avg = window.reduce(0) { $0 + $1.averageRPE } / Double(window.count)
            guard avg.isFinite, !avg.isNaN else { continue }
            result.append(ChartDataPoint(date: data[i].date, value: avg))
        }
        return result
    }

    private var weekAverageRPE: String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return nil }

        let thisWeek = data.filter { $0.date >= weekAgo }
        guard !thisWeek.isEmpty else { return nil }

        let avg = thisWeek.reduce(0) { $0 + $1.averageRPE } / Double(thisWeek.count)
        guard avg.isFinite, !avg.isNaN else { return nil }
        return String(localized: "Avg RPE \(String(format: "%.1f", avg))")
    }
}
