import SwiftUI
import Charts

struct HabitCompletionChartView: View {
    let weeklyRates: [WeeklyCompletionRate]
    let monthlyRates: [MonthlyCompletionRate]
    @State private var selectedPeriod: ChartPeriod = .weekly

    enum ChartPeriod: String, CaseIterable {
        case weekly, monthly

        var displayName: String {
            switch self {
            case .weekly:  String(localized: "Weekly")
            case .monthly: String(localized: "Monthly")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Label {
                    Text("Completion Rate")
                        .font(.headline)
                } icon: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(DS.Color.tabLife)
                }

                Spacer()

                Picker("Period", selection: $selectedPeriod) {
                    ForEach(ChartPeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            chartContent
                .chartPlotStyle { plotContent in
                    plotContent.frame(height: 160)
                }
                .clipped()
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
        .accessibilityIdentifier("habit-completion-chart")
    }

    @ViewBuilder
    private var chartContent: some View {
        switch selectedPeriod {
        case .weekly:
            weeklyChart
        case .monthly:
            monthlyChart
        }
    }

    private var weeklyChart: some View {
        Chart(weeklyRates) { rate in
            BarMark(
                x: .value("Week", rate.weekStart, unit: .weekOfYear),
                y: .value("Rate", rate.rate)
            )
            .foregroundStyle(DS.Color.tabLife.gradient)
            .cornerRadius(4)
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v * 100))%")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.narrow).day())
            }
        }
    }

    private var monthlyChart: some View {
        Chart(monthlyRates) { rate in
            BarMark(
                x: .value("Month", rate.monthStart, unit: .month),
                y: .value("Rate", rate.rate)
            )
            .foregroundStyle(DS.Color.tabLife.gradient)
            .cornerRadius(4)
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v * 100))%")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
    }
}
