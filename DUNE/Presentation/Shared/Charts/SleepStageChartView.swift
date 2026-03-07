import SwiftUI
import Charts

/// Sleep stage chart with two display modes:
/// - Day: Horizontal timeline showing stage transitions throughout the night.
/// - Week/Month+: Stacked bar chart showing daily total sleep with stage breakdown.
struct SleepStageChartView: View {
    let stages: [SleepStage]
    let dailyData: [StackedDataPoint]
    let period: TimePeriod
    var tintColor: Color = DS.Color.sleep
    @Binding var scrollPosition: Date

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    @Environment(\.appTheme) private var theme

    @State private var selectedDate: Date?
    @State private var selectionGestureState = ChartSelectionGestureState()
    @State private var activationTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if period == .day {
                dayTimelineChart
            } else {
                stackedBarChart
            }

            legend
        }
    }

    // MARK: - Day Timeline

    private var stackedChartDescriptor: SleepChartAccessibility {
        SleepChartAccessibility(title: "Sleep Duration", data: dailyData)
    }

    private var dayTimelineChart: some View {
        Chart {
            ForEach(Array(stages.enumerated()), id: \.offset) { _, stage in
                BarMark(
                    xStart: .value("Start", stage.startDate),
                    xEnd: .value("End", stage.endDate),
                    y: .value("Stage", stage.stage.label)
                )
                .foregroundStyle(stage.stage.color)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                    .foregroundStyle(theme.sandColor)
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
            }
        }
        .frame(height: chartHeight)
            .clipped()
        .drawingGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep stages timeline, \(stages.count) stages")
    }

    // MARK: - Stacked Bar Chart

    private var stackedBarChart: some View {
        Chart {
            ForEach(dailyData) { dataPoint in
                ForEach(dataPoint.segments, id: \.category) { segment in
                    BarMark(
                        x: .value("Date", dataPoint.date, unit: barXUnit),
                        y: .value("Hours", segment.value / 3600)
                    )
                    .foregroundStyle(segmentColor(segment.category))
                }
            }

            if let point = selectedDailyPoint {
                RuleMark(x: .value("Selected", point.date, unit: barXUnit))
                    .foregroundStyle(theme.accentColor.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartScrollableAxes(.horizontal)
        .scrollDisabled(!selectionGestureState.allowsScroll)
        .chartXVisibleDomain(length: period.visibleDomainSeconds)
        .chartScrollPosition(x: $scrollPosition)
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

                        if let point = selectedDailyPoint,
                           let anchor = selectedAnchor(for: point, proxy: proxy, plotFrame: plotFrame) {
                            FloatingChartSelectionOverlay(
                                date: point.date,
                                value: (point.total / 60).hoursMinutesFormatted,
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
        .sensoryFeedback(.selection, trigger: selectedDailyPoint?.date)
        .frame(height: chartHeight)
            .clipped()
        .accessibilityChartDescriptor(stackedChartDescriptor)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: DS.Spacing.lg) {
            ForEach([SleepStage.Stage.deep, .core, .rem, .awake], id: \.rawValue) { stage in
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(stage.color)
                        .frame(width: 8, height: 8)
                    Text(stage.label)
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func segmentColor(_ category: String) -> Color {
        let stage: SleepStage.Stage? = switch category {
        case "Deep": .deep
        case "Core": .core
        case "REM": .rem
        case "Awake": .awake
        case "Asleep": .unspecified
        default: nil
        }
        return stage?.color ?? .gray
    }

    private var barXUnit: Calendar.Component {
        switch period {
        case .day:        .hour
        case .sixMonths:  .weekOfYear
        case .year:       .month
        default:          .day
        }
    }

    /// Y-axis domain with top padding to prevent clipping.
    private var yDomain: ClosedRange<Double> {
        guard let maxVal = dailyData.map(\.total).max(), maxVal > 0 else {
            return 0...12
        }
        let maxHours = maxVal / 3600
        let padding = maxHours * 0.1
        return 0...(maxHours + padding)
    }

    private var selectedDailyPoint: StackedDataPoint? {
        guard let selectedDate else { return nil }
        return ChartSelectionInteraction.nearestPoint(to: selectedDate, in: dailyData, date: \.date)
    }

    private func selectedAnchor(
        for point: StackedDataPoint,
        proxy: ChartProxy,
        plotFrame: CGRect
    ) -> CGPoint? {
        ChartSelectionInteraction.anchor(
            xPosition: proxy.position(forX: point.date),
            yPosition: proxy.position(forY: point.total / 3600),
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
                        activationTask = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(ChartSelectionInteraction.holdDuration))
                            guard !Task.isCancelled else { return }
                            let result = selectionGestureState.forceActivate()
                            if case .activated(let restoreScrollPosition) = result {
                                if let restoreScrollPosition {
                                    scrollPosition = restoreScrollPosition
                                }
                                selectedDate = ChartSelectionInteraction.resolvedDate(
                                    at: location,
                                    proxy: proxy,
                                    plotFrame: plotFrame
                                )
                            }
                        }
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
