import SwiftUI
import Charts

/// Reusable 14-day trend chart for a single sub-score metric (HRV, RHR, Sleep).
struct SubScoreTrendChartView: View {
    let title: String
    let data: [ChartDataPoint]
    let color: Color
    let unit: String
    var fractionDigits: Int = 0

    @State private var selectedDate: Date?

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
                        .foregroundStyle(.secondary)
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
        Chart(data) { point in
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

            if let selected = selectedDate,
               Calendar.current.isDate(point.date, inSameDayAs: selected) {
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(title, point.value)
                )
                .foregroundStyle(color)
                .symbolSize(40)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXSelection(value: $selectedDate)
        .sensoryFeedback(.selection, trigger: selectedDate)
        .overlay(alignment: .top) {
            if let selected = selectedDate,
               let point = data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selected) }) {
                ChartSelectionOverlay(
                    date: point.date,
                    value: "\(formatValue(point.value)) \(unit)"
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: selectedDate)
            }
        }
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
}
