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
    var scrollPosition: Binding<Date>?

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    @State private var selectedDate: Date?
    @State private var internalScrollPosition: Date = .now

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
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Selected point info
            if let selected = selectedPoint {
                HStack {
                    Text(selected.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.1f", selected.value))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.secondary)
                .transition(.opacity)
            }

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
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartScrollableAxes(timePeriod != nil ? .horizontal : [])
            .modifier(DotLineScrollModifier(
                timePeriod: timePeriod,
                scrollPosition: scrollPosition ?? $internalScrollPosition
            ))
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: xStrideComponent, count: xStrideCount)) { _ in
                    AxisValueLabel(format: axisFormat)
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
            .accessibilityLabel("\(yAxisLabel) chart, \(data.count) data points")
            .accessibilityValue(accessibilitySummary)
        }
    }

    private var accessibilitySummary: String {
        guard !data.isEmpty else { return "No data" }
        let values = data.map(\.value)
        let avg = values.reduce(0, +) / Double(values.count)
        return "Average \(String(format: "%.1f", avg))"
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
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
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
