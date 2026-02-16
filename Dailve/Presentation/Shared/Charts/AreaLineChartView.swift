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
    @Binding var scrollPosition: Date

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            selectionHeader

            Chart {
                ForEach(data) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: xUnit),
                        y: .value("Weight", point.value)
                    )
                    .foregroundStyle(areaGradient)
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
            .accessibilityLabel("Weight trend chart, \(data.count) data points")
            .accessibilityValue(accessibilitySummary)
        }
    }

    private var accessibilitySummary: String {
        guard !data.isEmpty else { return "No data" }
        let values = data.map(\.value)
        let latest = values.last ?? 0
        return "Latest \(String(format: "%.1f", latest)) \(unitSuffix)"
    }

    // MARK: - Subviews

    @ViewBuilder
    private var selectionHeader: some View {
        if let point = selectedPoint {
            HStack {
                Text(point.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f %@", point.value, unitSuffix))
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
        case .day:       .hour
        case .sixMonths: .weekOfYear
        case .year:      .month
        default:         .day
        }
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [tintColor.opacity(0.3), tintColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
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
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }
}
