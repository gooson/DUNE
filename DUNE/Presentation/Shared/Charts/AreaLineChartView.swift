import SwiftUI
import Charts

/// Area line chart for Weight trends.
/// Shows a line with gradient fill area underneath, using Catmull-Rom interpolation.
struct AreaLineChartView: View {
    let data: [ChartDataPoint]
    let period: TimePeriod
    var tintColor: Color = DS.Color.body
    var unitSuffix: String = "kg"
    var trendLine: [ChartDataPoint]?
    var scrollDomain: ClosedRange<Date>?
    @Binding var scrollPosition: Date

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    @Environment(\.appTheme) private var theme

    @State private var selectedDate: Date?
    @State private var selectionGestureState = ChartSelectionGestureState()
    @State private var activationTask: Task<Void, Never>?

    // Correction #105/#165 — computed gradient using theme
    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [tintColor.opacity(0.22), theme.accentColor.opacity(DS.Opacity.subtle), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        // Correction #105/#165 — capture gradient before ForEach to avoid per-row allocation
        let resolvedAreaGradient = areaGradient
        Chart {
                ForEach(data) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: xUnit),
                        y: .value("Weight", point.value)
                    )
                    .foregroundStyle(resolvedAreaGradient)
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date, unit: xUnit),
                        y: .value("Weight", point.value)
                    )
                    .foregroundStyle(tintColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
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
                        y: .value("Weight", point.value)
                    )
                    .foregroundStyle(tintColor)
                    .symbolSize(48)

                    RuleMark(x: .value("Selected", point.date, unit: xUnit))
                        .foregroundStyle(theme.accentColor.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartScrollableAxes(.horizontal)
            .scrollDisabled(!selectionGestureState.allowsScroll)
            .chartXVisibleDomain(length: period.visibleDomainSeconds)
            .chartScrollPosition(x: $scrollPosition)
            .chartXScale(domain: effectiveXDomain)
            .chartYScale(domain: yDomain)
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
                                    value: "\(point.value.formattedWithSeparator(fractionDigits: 1)) \(unitSuffix)",
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

    private var chartDescriptor: StandardChartAccessibility {
        StandardChartAccessibility(title: "Weight", data: data, unitSuffix: unitSuffix)
    }

    // MARK: - Helpers

    private var xUnit: Calendar.Component {
        switch period {
        case .day:       .hour
        case .sixMonths: .weekOfYear
        case .year:      .month
        default:         .day
        }
    }


    /// X-axis domain: explicit scroll domain if provided, otherwise derived from data points.
    private var effectiveXDomain: ClosedRange<Date> {
        if let scrollDomain { return scrollDomain }
        guard let first = data.min(by: { $0.date < $1.date })?.date,
              let last = data.max(by: { $0.date < $1.date })?.date,
              first < last else {
            let now = Date()
            return now...now.addingTimeInterval(1)
        }
        return first...last
    }

    /// Y-axis domain with padding around min/max values.
    private var yDomain: ClosedRange<Double> {
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

    private func selectionGesture(proxy: ChartProxy, plotFrame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let update = selectionGestureState.registerChange(
                    at: value.time,
                    translation: value.translation,
                    currentScrollPosition: scrollPosition
                )
                switch update {
                case .inactive:
                    if selectionGestureState.phase == .pendingActivation, activationTask == nil {
                        let location = value.location
                        activationTask = ChartSelectionInteraction.makeActivationTask(
                            location: location, proxy: proxy, plotFrame: plotFrame,
                            activate: { selectionGestureState.forceActivate() },
                            onActivated: { date, restoreScroll in
                                if let restoreScroll { scrollPosition = restoreScroll }
                                selectedDate = date
                            }
                        )
                    }
                    return
                case .activated(let restoreScrollPosition):
                    activationTask?.cancel()
                    activationTask = nil
                    if let restoreScrollPosition {
                        scrollPosition = restoreScrollPosition
                    }
                    fallthrough
                case .updating:
                    if let restore = selectionGestureState.initialScrollPosition,
                       scrollPosition != restore {
                        scrollPosition = restore
                    }
                    selectedDate = ChartSelectionInteraction.resolvedDate(
                        at: value.location,
                        proxy: proxy,
                        plotFrame: plotFrame
                    )
                }
            }
            .onEnded { _ in
                activationTask?.cancel()
                activationTask = nil
                selectionGestureState.reset()
                selectedDate = nil
            }
    }
}
