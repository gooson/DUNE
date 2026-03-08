import SwiftUI
import Charts

/// Reusable 14-day trend chart for a single sub-score metric (HRV, RHR, Sleep).
struct SubScoreTrendChartView: View {
    let title: LocalizedStringKey
    let data: [ChartDataPoint]
    let color: Color
    let unit: String
    var fractionDigits: Int = 0

    @Environment(\.appTheme) private var theme

    @State private var selectedDate: Date?
    @State private var selectionGestureState = ChartSelectionGestureState()

    private enum Cache {
        static let numberFormatter: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 1
            return f
        }()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let avg = averageValue {
                    Text("Avg \(formatValue(avg)) \(unit)")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            if data.isEmpty {
                Text("Not enough data.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                chartView
                    .frame(height: 120)
                    .clipped()
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Chart

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.2), color.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var chartView: some View {
        Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(title, point.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(title, point.value)
                )
                .foregroundStyle(areaGradient)
                .interpolationMethod(.catmullRom)
            }

            if let point = selectedPoint {
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(title, point.value)
                )
                .foregroundStyle(color)
                .symbolSize(40)

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
        .chartYScale(domain: yDomain)
        .scrollableChartSelectionOverlay(
            isScrollable: false,
            visibleDomainLength: nil,
            scrollPosition: nil,
            selectedDate: $selectedDate,
            selectionState: $selectionGestureState
        ) { proxy, plotFrame, chartSize in
            if let point = selectedPoint,
               let anchor = selectedAnchor(for: point, proxy: proxy, plotFrame: plotFrame) {
                FloatingChartSelectionOverlay(
                    date: point.date,
                    value: "\(formatValue(point.value)) \(unit)",
                    anchor: anchor,
                    chartSize: chartSize,
                    plotFrame: plotFrame
                )
                .transition(.opacity)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedPoint?.date)
    }

    // MARK: - Helpers

    private var averageValue: Double? {
        guard !data.isEmpty else { return nil }
        let sum = data.map(\.value).reduce(0, +)
        let avg = sum / Double(data.count)
        return avg.isFinite ? avg : nil
    }

    private var yDomain: ClosedRange<Double> {
        let values = data.map(\.value)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        let padding = Swift.max((maxVal - minVal) * 0.15, 1)
        return Swift.max(0, minVal - padding)...(maxVal + padding)
    }

    private func formatValue(_ value: Double) -> String {
        if fractionDigits == 0 {
            return Int(value).formattedWithSeparator
        }
        return value.formattedWithSeparator(fractionDigits: fractionDigits)
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
