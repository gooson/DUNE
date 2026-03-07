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
    @State private var activationTask: Task<Void, Never>?

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
            .chartScrollableAxes(timePeriod != nil ? .horizontal : [])
            .scrollDisabled(!selectionGestureState.allowsScroll)
            .modifier(DotLineScrollModifier(
                timePeriod: timePeriod,
                scrollPosition: scrollPosition ?? $internalScrollPosition
            ))
            .chartYScale(domain: yDomain)
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

                            if let selected = selectedPoint,
                               let anchor = selectedAnchor(for: selected, proxy: proxy, plotFrame: plotFrame) {
                                FloatingChartSelectionOverlay(
                                    date: selected.date,
                                    value: selected.value.formattedWithSeparator(fractionDigits: 1),
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
        return .day
    }

    private var xStrideCount: Int {
        if let timePeriod {
            return timePeriod.strideCount
        }
        return period == .week ? 1 : 7
    }

    private var axisFormat: Date.FormatStyle {
        if let timePeriod {
            return timePeriod.axisLabelFormat
        }
        return .dateTime.day().month(.abbreviated)
    }

    private var effectiveXDomain: ClosedRange<Date> {
        resolvedXDomain(scrollDomain: scrollDomain, dates: data.map(\.date))
    }

    /// Y-axis domain with padding to prevent top/bottom clipping.
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
                    currentScrollPosition: scrollPosition?.wrappedValue
                )
                switch update {
                case .inactive:
                    if selectionGestureState.phase == .pendingActivation, activationTask == nil {
                        let location = value.location
                        activationTask = ChartSelectionInteraction.makeActivationTask(
                            location: location, proxy: proxy, plotFrame: plotFrame,
                            activate: { selectionGestureState.forceActivate() },
                            onActivated: { date, restoreScroll in
                                if let restoreScroll { scrollPosition?.wrappedValue = restoreScroll }
                                selectedDate = date
                            }
                        )
                    }
                    return
                case .activated(let restoreScrollPosition):
                    activationTask?.cancel()
                    activationTask = nil
                    if let restoreScrollPosition {
                        scrollPosition?.wrappedValue = restoreScrollPosition
                    }
                    fallthrough
                case .updating:
                    if let restore = selectionGestureState.initialScrollPosition,
                       scrollPosition?.wrappedValue != restore {
                        scrollPosition?.wrappedValue = restore
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
