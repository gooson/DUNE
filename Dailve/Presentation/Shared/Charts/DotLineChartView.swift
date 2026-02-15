import SwiftUI
import Charts

struct DotLineChartView: View {
    let data: [ChartDataPoint]
    let baseline: Double?
    let yAxisLabel: String
    var period: Period = .week
    var timePeriod: TimePeriod?
    var tintColor: Color = DS.Color.hrv

    @State private var selectedDate: Date?

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
        }
    }

    // MARK: - Helpers

    private var xUnit: Calendar.Component {
        if let timePeriod {
            return timePeriod == .day ? .hour : .day
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

    private var selectedPoint: ChartDataPoint? {
        guard let selectedDate else { return nil }
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }
}
