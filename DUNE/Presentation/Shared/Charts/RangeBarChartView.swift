import SwiftUI
import Charts

/// Range bar chart for RHR (min-max capsule bars with average line).
/// Each bar shows the min-max range for a time unit, with a line marking the average.
struct RangeBarChartView: View {
    let data: [RangeDataPoint]
    let period: TimePeriod
    var tintColor: Color = DS.Color.rhr
    var trendLine: [ChartDataPoint]?
    var scrollDomain: ClosedRange<Date>?
    @Binding var scrollPosition: Date

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    @Environment(\.appTheme) private var theme

    @State private var selectedDate: Date?
    @State private var selectionGestureState = ChartSelectionGestureState()

    private enum Labels {
        static let average = String(localized: "Avg")
    }

    var body: some View {
        Chart {
                ForEach(data) { point in
                    // Capsule bar for min-max range
                    BarMark(
                        x: .value("Date", point.date, unit: xUnit),
                        yStart: .value("Min", point.min),
                        yEnd: .value("Max", point.max),
                        width: barWidth
                    )
                    .foregroundStyle(barColor(for: point))
                    .clipShape(Capsule())
                }

                // Average trend line
                ForEach(data) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: xUnit),
                        y: .value("Avg", point.average)
                    )
                    .foregroundStyle(tintColor.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
                }

                // Trend line (linear regression)
                if let trendLine, trendLine.count >= 2 {
                    ForEach(trendLine) { point in
                        LineMark(
                            x: .value("Trend", point.date),
                            y: .value("TrendValue", point.value),
                            series: .value("Series", "trend")
                        )
                        .foregroundStyle(tintColor.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .interpolationMethod(.linear)
                    }
                }

                if let point = selectedPoint {
                    RuleMark(x: .value("Selected", point.date, unit: xUnit))
                        .foregroundStyle(theme.accentColor.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartScrollableAxes(.horizontal)
            .scrollDisabled(!selectionGestureState.allowsScroll)
            .chartXVisibleDomain(length: period.visibleDomainSeconds)
            .chartScrollPosition(x: $scrollPosition)
            .chartYScale(domain: yDomain)
            .chartXScale(domain: effectiveXDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: period.strideComponent, count: period.strideCount)) { _ in
                    AxisValueLabel(format: period.axisLabelFormat)
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
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let plotFrame = proxy.plotFrame.map({ geometry[$0] }) {
                        ZStack(alignment: .topLeading) {
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .simultaneousGesture(
                                    selectionGesture(proxy: proxy, plotFrame: plotFrame)
                                )

                            if let point = selectedPoint,
                               let anchor = selectedAnchor(for: point, proxy: proxy, plotFrame: plotFrame) {
                                FloatingChartSelectionOverlay(
                                    date: point.date,
                                    value: "\(Int(point.min).formattedWithSeparator)–\(Int(point.max).formattedWithSeparator) bpm (\(Labels.average) \(Int(point.average).formattedWithSeparator))",
                                    anchor: anchor,
                                    chartSize: geometry.size,
                                    plotFrame: plotFrame
                                )
                                .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.15), value: selectedDate)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedPoint?.date)
            .frame(height: chartHeight)
            .clipped()
            .accessibilityChartDescriptor(chartDescriptor)
    }

    private var chartDescriptor: RangeChartAccessibility {
        RangeChartAccessibility(title: "Resting Heart Rate", data: data, unitSuffix: "bpm")
    }

    // MARK: - Helpers

    private var xUnit: Calendar.Component {
        switch period {
        case .day:        .hour
        case .sixMonths:  .weekOfYear
        case .year:       .month
        default:          .day
        }
    }

    private var barWidth: MarkDimension {
        switch period {
        case .day:        .fixed(6)
        case .week:       .fixed(12)
        case .month:      .fixed(6)
        case .sixMonths:  .fixed(8)
        case .year:       .fixed(16)
        }
    }

    private var effectiveXDomain: ClosedRange<Date> {
        resolvedXDomain(scrollDomain: scrollDomain, dates: data.map(\.date))
    }

    /// Y-axis domain with padding to prevent clipping.
    private var yDomain: ClosedRange<Double> {
        guard let minVal = data.map(\.min).min(),
              let maxVal = data.map(\.max).max() else {
            return 40...100
        }
        let range = maxVal - minVal
        let padding = max(range * 0.15, 2)
        return (minVal - padding)...(maxVal + padding)
    }

    private var selectedPoint: RangeDataPoint? {
        guard let selectedDate else { return nil }
        return ChartSelectionInteraction.nearestPoint(to: selectedDate, in: data, date: \.date)
    }

    private func barColor(for point: RangeDataPoint) -> Color {
        if selectedDate != nil {
            return point.id == selectedPoint?.id ? tintColor : tintColor.opacity(0.3)
        }
        return tintColor
    }

    private func selectedAnchor(
        for point: RangeDataPoint,
        proxy: ChartProxy,
        plotFrame: CGRect
    ) -> CGPoint? {
        ChartSelectionInteraction.anchor(
            xPosition: proxy.position(forX: point.date),
            yPosition: proxy.position(forY: point.average),
            plotFrame: plotFrame
        )
    }

    private func selectionGesture(proxy: ChartProxy, plotFrame: CGRect) -> some Gesture {
        LongPressGesture(minimumDuration: ChartSelectionInteraction.holdDuration)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                guard case .second(true, let drag) = value, let drag else { return }
                selectionGestureState.beginSelection(scrollPosition: scrollPosition)
                if let restore = selectionGestureState.initialScrollPosition,
                   scrollPosition != restore {
                    scrollPosition = restore
                }
                selectedDate = ChartSelectionInteraction.resolvedDate(
                    at: drag.location,
                    proxy: proxy,
                    plotFrame: plotFrame
                )
            }
            .onEnded { _ in
                selectionGestureState.reset()
                selectedDate = nil
            }
    }

}
