import SwiftUI
import Charts

struct DotLineChartView: View {
    let data: [ChartDataPoint]
    let baseline: Double?
    let yAxisLabel: String
    var period: Period = .week
    var timePeriod: TimePeriod?
    var tintColor: Color = DS.Color.hrv
    var trendLine: [ChartDataPoint]?
    var scrollDomain: ClosedRange<Date>?
    var scrollPosition: Binding<Date>?

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    @Environment(\.appTheme) private var theme

    @State private var selectedDate: Date?
    @State private var internalScrollPosition: Date = .now
    @State private var selectionGestureState = ChartSelectionGestureState()
    @State private var lastSelectionProbeLabel = "none"
    @State private var cachedYDomain: ClosedRange<Double> = 0...100
    enum Period: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case quarter = "90D"

        var days: Int {
            switch self {
            case .week: 7
            case .month: 30
            case .quarter: 90
            }
        }
    }

    var body: some View {
        Chart {
                ForEach(data) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: xUnit),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tintColor.opacity(0.6))

                    // Hide points when data is dense (>30 points)
                    if data.count <= 30 {
                        PointMark(
                            x: .value("Date", point.date, unit: xUnit),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(tintColor)
                        .symbolSize(24)
                    }
                }

                // Baseline
                if let baseline {
                    RuleMark(y: .value("Baseline", baseline))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }

                // Trend line
                if let trendLine, trendLine.count >= 2 {
                    ForEach(trendLine) { point in
                        LineMark(
                            x: .value("Trend", point.date),
                            y: .value("TrendValue", point.value),
                            series: .value("Series", "trend")
                        )
                        .foregroundStyle(tintColor.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .interpolationMethod(.linear)
                    }
                }

                // Selection indicator
                if let point = selectedPoint {
                    PointMark(
                        x: .value("Date", point.date, unit: xUnit),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(tintColor)
                    .symbolSize(48)

                    RuleMark(x: .value("Selected", point.date, unit: xUnit))
                        .foregroundStyle(theme.accentColor.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .modifier(DotLineScrollModifier(
                timePeriod: timePeriod,
                scrollPosition: scrollPosition ?? $internalScrollPosition
            ))
            .chartYScale(domain: cachedYDomain)
            .chartXScale(domain: effectiveXDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: xStrideComponent, count: xStrideCount)) { _ in
                    AxisValueLabel(format: axisFormat)
                        .foregroundStyle(theme.sandColor)
                    AxisGridLine()
                        .foregroundStyle(theme.accentColor.opacity(0.30))
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
            .scrollableChartSelectionOverlay(
                isScrollable: timePeriod != nil,
                visibleDomainLength: timePeriod?.visibleDomainSeconds,
                scrollPosition: scrollPosition ?? $internalScrollPosition,
                selectedDate: $selectedDate,
                selectionState: $selectionGestureState
            ) { proxy, plotFrame, chartSize in
                if let selected = selectedPoint,
                   let anchor = selectedAnchor(for: selected, proxy: proxy, plotFrame: plotFrame) {
                    FloatingChartSelectionOverlay(
                        date: selected.date,
                        value: selected.value.formattedWithSeparator(fractionDigits: 1),
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
            .accessibilityChartDescriptor(chartDescriptor)
            .chartSelectionUITestProbe(lastSelectionProbeLabel)
            .frame(height: chartHeight)
            .clipped()
            .chartDrawAnimation()
            .onAppear { cachedYDomain = Self.computeYDomain(from: data) }
            .onChange(of: data.count) { _, _ in cachedYDomain = Self.computeYDomain(from: data) }
    }

    private var chartDescriptor: StandardChartAccessibility {
        StandardChartAccessibility(title: yAxisLabel, data: data, unitSuffix: yAxisLabel)
    }

    // MARK: - Helpers

    private var xUnit: Calendar.Component {
        if let timePeriod {
            switch timePeriod {
            case .day:       return .hour
            case .sixMonths: return .weekOfYear
            case .year:      return .month
            default:         return .day
            }
        }
        return .day
    }

    private var xStrideComponent: Calendar.Component {
        if let timePeriod {
            return timePeriod.strideComponent
        }
        if dataSpanDays > 180 { return .month }
        return .day
    }

    private var xStrideCount: Int {
        if let timePeriod {
            return timePeriod.strideCount
        }
        let span = dataSpanDays
        if span <= 14 { return 2 }
        if span <= 60 { return 7 }
        if span <= 180 { return 14 }
        return 1 // .month component → every month
    }

    private var axisFormat: Date.FormatStyle {
        if let timePeriod {
            return timePeriod.axisLabelFormat
        }
        let span = dataSpanDays
        if span <= 14 { return .dateTime.day().month(.abbreviated) }
        if span <= 180 { return .dateTime.month(.narrow).day() }
        return .dateTime.month(.abbreviated)
    }

    private var dataSpanDays: Int {
        guard let first = data.first?.date, let last = data.last?.date else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0)
    }

    private var effectiveXDomain: ClosedRange<Date> {
        resolvedXDomain(scrollDomain: scrollDomain, dates: data.map(\.date))
    }

    /// Recompute Y-axis domain from data.
    private static func computeYDomain(from data: [ChartDataPoint]) -> ClosedRange<Double> {
        guard let minVal = data.map(\.value).min(),
              let maxVal = data.map(\.value).max() else {
            return 0...100
        }
        let padding = max((maxVal - minVal) * 0.15, 2)
        return (minVal - padding)...(maxVal + padding)
    }

    private var selectedPoint: ChartDataPoint? {
        guard let selectedDate else { return nil }
        return ChartSelectionInteraction.nearestPoint(to: selectedDate, in: data, date: \.date)
    }

    private func selectedAnchor(
        for point: ChartDataPoint,
        proxy: ChartProxy,
        plotFrame: CGRect
    ) -> CGPoint? {
        ChartSelectionInteraction.anchor(
            xPosition: proxy.position(forX: point.date),
            yPosition: proxy.position(forY: point.value),
            plotFrame: plotFrame
        )
    }

}

/// Applies chartXVisibleDomain + chartScrollPosition only when timePeriod is set.
private struct DotLineScrollModifier: ViewModifier {
    let timePeriod: TimePeriod?
    @Binding var scrollPosition: Date

    func body(content: Content) -> some View {
        if let timePeriod {
            content
                .chartXVisibleDomain(length: timePeriod.visibleDomainSeconds)
                .chartScrollPosition(x: $scrollPosition)
        } else {
            content
        }
    }
}
