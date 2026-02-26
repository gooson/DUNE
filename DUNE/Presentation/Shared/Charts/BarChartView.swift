import SwiftUI
import Charts

/// Bar chart for Steps and Exercise metrics.
/// Supports period-aware x-axis stride, scrollable horizontal axis, and selection interaction.
struct BarChartView: View {
    let data: [ChartDataPoint]
    let period: TimePeriod
    var tintColor: Color = DS.Color.steps
    var valueLabel: String = "Value"
    var unitSuffix: String = ""
    var trendLine: [ChartDataPoint]?
    @Binding var scrollPosition: Date

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    @State private var selectedDate: Date?

    var body: some View {
        Chart {
                ForEach(data) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: xUnit),
                        y: .value(valueLabel, point.value),
                        width: barWidth
                    )
                    .foregroundStyle(barColor(for: point))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                // Trend line
                if let trendLine, trendLine.count >= 2 {
                    ForEach(trendLine) { point in
                        LineMark(
                            x: .value("Trend", point.date),
                            y: .value("TrendValue", point.value),
                            series: .value("Series", "trend")
                        )
                        .foregroundStyle(tintColor.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .interpolationMethod(.linear)
                    }
                }

                if selectedDate != nil, let point = selectedPoint {
                    RuleMark(x: .value("Selected", point.date, unit: xUnit))
                        .foregroundStyle(DS.Color.warmGlow.opacity(0.25))
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
                        .foregroundStyle(DS.Color.sandMuted)
                    AxisGridLine()
                        .foregroundStyle(DS.Color.warmGlow.opacity(0.20))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(DS.Color.sandMuted)
                    AxisGridLine()
                        .foregroundStyle(DS.Color.warmGlow.opacity(0.20))
                }
            }
            .chartXSelection(value: $selectedDate)
            .sensoryFeedback(.selection, trigger: selectedDate)
            .frame(height: chartHeight)
            .accessibilityChartDescriptor(chartDescriptor)
            .overlay(alignment: .top) {
                if let point = selectedPoint {
                    ChartSelectionOverlay(
                        date: point.date,
                        value: "\(point.value.formattedWithSeparator())\(unitSuffix)",
                        dateFormat: headerDateFormat
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: selectedDate)
                }
            }
    }

    private var chartDescriptor: StandardChartAccessibility {
        StandardChartAccessibility(title: valueLabel, data: data, unitSuffix: unitSuffix, valueFormat: "%.0f")
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
        case .day:        .automatic
        case .week:       .automatic
        case .month:      .automatic
        case .sixMonths:  .fixed(8)
        case .year:       .fixed(16)
        }
    }

    /// Y-axis domain with top padding to prevent clipping.
    private var yDomain: ClosedRange<Double> {
        guard let maxVal = data.map(\.value).max(), maxVal > 0 else {
            return 0...100
        }
        let padding = maxVal * 0.1
        return 0...(maxVal + padding)
    }

    private var selectedPoint: ChartDataPoint? {
        guard let selectedDate else { return nil }
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private func barColor(for point: ChartDataPoint) -> Color {
        if selectedDate != nil {
            return point.id == selectedPoint?.id ? tintColor : tintColor.opacity(0.3)
        }
        return tintColor
    }

    private var headerDateFormat: Date.FormatStyle {
        period == .day ? .dateTime.hour().minute() : .dateTime.month(.abbreviated).day()
    }

}
