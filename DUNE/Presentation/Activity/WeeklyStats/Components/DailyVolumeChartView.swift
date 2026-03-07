import SwiftUI
import Charts

/// Daily volume bar chart showing duration/calories per day within the selected period.
struct DailyVolumeChartView: View {
    let dailyBreakdown: [DailyVolumePoint]

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
    @State private var selectionGestureState = ChartSelectionGestureState()

    private enum Gradients {
        static let bar = LinearGradient(
            colors: [DS.Color.activity, DS.Color.activity.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Daily Breakdown")
                    .font(.subheadline.weight(.semibold))
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
                    .id(selectedMetric)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: selectedMetric)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
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
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame.map({ geometry[$0] }) {
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                selectionGesture(proxy: proxy, plotFrame: plotFrame),
                                including: .subviews
                            )

                        if let point = selectedPoint,
                           let anchor = selectedAnchor(for: point, proxy: proxy, plotFrame: plotFrame) {
                            FloatingChartSelectionOverlay(
                                date: point.date,
                                value: formattedValue(point),
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

    // MARK: - Helpers

    private var selectedPoint: DailyVolumePoint? {
        guard let selectedDate else { return nil }
        return ChartSelectionInteraction.nearestPoint(to: selectedDate, in: dailyBreakdown, date: \.date)
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

    private func selectionGesture(proxy: ChartProxy, plotFrame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                switch selectionGestureState.registerChange(
                    at: value.time,
                    translation: value.translation
                ) {
                case .inactive:
                    return
                case .activated, .updating:
                    selectedDate = ChartSelectionInteraction.resolvedDate(
                        at: value.location,
                        proxy: proxy,
                        plotFrame: plotFrame
                    )
                }
            }
            .onEnded { _ in
                selectionGestureState.reset()
                selectedDate = nil
            }
    }
}
