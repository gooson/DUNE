import SwiftUI
import Charts

/// Bar chart for Steps and Exercise metrics.
/// Supports period-aware x-axis stride and selection interaction.
struct BarChartView: View {
    let data: [ChartDataPoint]
    let period: TimePeriod
    var tintColor: Color = DS.Color.steps
    var valueLabel: String = "Value"
    var unitSuffix: String = ""

    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            selectionHeader

            Chart {
                ForEach(data) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: xUnit),
                        y: .value(valueLabel, point.value)
                    )
                    .foregroundStyle(barColor(for: point))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                if selectedDate != nil, let point = selectedPoint {
                    RuleMark(x: .value("Selected", point.date, unit: xUnit))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
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
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var selectionHeader: some View {
        if let point = selectedPoint {
            HStack {
                Text(point.date, format: headerDateFormat)
                    .font(.caption)
                Spacer()
                Text("\(String(format: "%.0f", point.value))\(unitSuffix)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.secondary)
            .transition(.opacity)
        }
    }

    // MARK: - Helpers

    private var xUnit: Calendar.Component {
        period == .day ? .hour : .day
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
