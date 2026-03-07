import SwiftUI
import Charts

/// 14-day training readiness score trend line chart.
struct ReadinessTrendChartView: View {
    let data: [ChartDataPoint]

    @Environment(\.appTheme) private var theme

    @State private var selectedDate: Date?
    @State private var selectionGestureState = ChartSelectionGestureState()
    @State private var activationTask: Task<Void, Never>?

    private enum Gradients {
        static let area = LinearGradient(
            colors: [DS.Color.activity.opacity(0.15), DS.Color.activity.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Readiness Trend")
                .font(.subheadline.weight(.semibold))

            if data.isEmpty {
                Text("Not enough data to show trend.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
            } else {
                chartView
                    .frame(height: 160)
                    .clipped()
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(colorForScore(point.value))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(Gradients.area)
                .interpolationMethod(.catmullRom)
            }

            if let point = selectedPoint {
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(colorForScore(point.value))
                .symbolSize(50)

                RuleMark(x: .value("Date", point.date, unit: .day))
                    .foregroundStyle(theme.accentColor.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    .foregroundStyle(theme.sandColor)
            }
        }
        .chartYScale(domain: 0...110)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .foregroundStyle(theme.sandColor)
                    }
                }
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
                                value: "\(Int(point.value))",
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
    }

    // MARK: - Color

    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 80...: DS.Color.scoreExcellent
        case 60..<80: DS.Color.scoreGood
        case 40..<60: DS.Color.scoreFair
        default: DS.Color.scoreWarning
        }
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
                    translation: value.translation
                )
                switch update {
                case .inactive:
                    if selectionGestureState.phase == .pendingActivation, activationTask == nil {
                        let location = value.location
                        activationTask = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(ChartSelectionInteraction.holdDuration))
                            guard !Task.isCancelled else { return }
                            let result = selectionGestureState.forceActivate()
                            if case .activated = result {
                                selectedDate = ChartSelectionInteraction.resolvedDate(
                                    at: location,
                                    proxy: proxy,
                                    plotFrame: plotFrame
                                )
                            }
                        }
                    }
                    return
                case .activated, .updating:
                    activationTask?.cancel()
                    activationTask = nil
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
