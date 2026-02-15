import SwiftUI
import Charts

struct DotLineChartView: View {
    let data: [ChartDataPoint]
    let baseline: Double?
    let yAxisLabel: String
    var period: Period = .week
    var tintColor: Color = DS.Color.hrv

    @State private var selectedPoint: ChartDataPoint?

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
        VStack(alignment: .leading, spacing: 8) {
            // Selected point info
            if let selected = selectedPoint {
                HStack {
                    Text(selected.date, style: .date)
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.1f", selected.value))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(data) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tintColor.opacity(0.6))

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(tintColor)
                    .symbolSize(24)
                }

                // Baseline
                if let baseline {
                    RuleMark(y: .value("Baseline", baseline))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 7)) { value in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = value.location.x - geometry[plotFrame].origin.x
                                    guard let date: Date = proxy.value(atX: x) else { return }
                                    selectedPoint = data.min(by: {
                                        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                    })
                                }
                                .onEnded { _ in
                                    selectedPoint = nil
                                }
                        )
                }
            }
        }
    }
}

struct ChartDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}
