import SwiftUI
import Charts

/// Range bar chart for RHR (min-max capsule bars with average line).
/// Each bar shows the min-max range for a time unit, with a line marking the average.
struct RangeBarChartView: View {
    let data: [RangeDataPoint]
    let period: TimePeriod
    var tintColor: Color = DS.Color.rhr
    var trendLine: [ChartDataPoint]?
    @Binding var scrollPosition: Date

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            selectionHeader

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
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: period.visibleDomainSeconds)
            .chartScrollPosition(x: $scrollPosition)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: period.strideComponent, count: period.strideCount)) { _ in
                    AxisValueLabel(format: period.axisLabelFormat)
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .chartXSelection(value: $selectedDate)
            .sensoryFeedback(.selection, trigger: selectedDate)
            .frame(height: chartHeight)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Resting heart rate chart, \(data.count) data points")
            .accessibilityValue(accessibilitySummary)
        }
    }

    private var accessibilitySummary: String {
        guard !data.isEmpty else { return "No data" }
        let avg = data.map(\.average).reduce(0, +) / Double(data.count)
        return "Average \(String(format: "%.0f", avg)) bpm"
    }

    // MARK: - Subviews

    @ViewBuilder
    private var selectionHeader: some View {
        if let point = selectedPoint {
            HStack {
                Text(point.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                Spacer()
                Text("\(Int(point.min))–\(Int(point.max)) bpm (avg \(Int(point.average)))")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.secondary)
            .transition(.opacity)
        }
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
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private func barColor(for point: RangeDataPoint) -> Color {
        if selectedDate != nil {
            return point.id == selectedPoint?.id ? tintColor : tintColor.opacity(0.3)
        }
        return tintColor
    }
}
