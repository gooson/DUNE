import SwiftUI
import Charts

struct HabitCompletionChartView: View {
    let weeklyRates: [WeeklyCompletionRate]
    let monthlyRates: [MonthlyCompletionRate]
    @State private var selectedPeriod: ChartPeriod = .weekly
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var accessibleAxisTopPadding: CGFloat = 16
    @ScaledMetric(relativeTo: .caption2) private var accessiblePlotHeight: CGFloat = 160

    private var plotHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? accessiblePlotHeight : 160
    }

    private var rateDomain: ClosedRange<Double> {
        dynamicTypeSize.isAccessibilitySize ? -0.125...1.125 : 0...1
    }

    private var accessibleWeeklyAxisDates: [Date] {
        guard let first = weeklyRates.first?.weekStart else { return [] }
        guard let last = weeklyRates.last?.weekStart, last != first else { return [first] }
        return [first, last]
    }

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
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Completion Rate")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("habit-completion-chart-title")

                    periodPicker
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    Label {
                        Text("Completion Rate")
                            .font(.headline)
                            .accessibilityIdentifier("habit-completion-chart-title")
                    } icon: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(DS.Color.tabLife)
                    }

                    Spacer()

                    periodPicker
                        .frame(width: 160)
                }
            }

            chartContent
                .chartPlotStyle { plotContent in
                    plotContent.frame(height: plotHeight).clipped()
                }
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? accessibleAxisTopPadding : 8)
                .frame(minHeight: 200)
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
        .accessibilityIdentifier("habit-completion-chart")
    }

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(ChartPeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
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
        .chartYScale(domain: rateDomain)
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
            if dynamicTypeSize.isAccessibilitySize {
                AxisMarks(values: accessibleWeeklyAxisDates) { value in
                    AxisGridLine()
                    AxisValueLabel(
                        format: .dateTime.month(.narrow).day(),
                        centered: false,
                        anchor: value.index == 0 ? .topLeading : .topTrailing,
                        collisionResolution: .greedy
                    )
                }
            } else {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.narrow).day())
                }
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
        .chartYScale(domain: rateDomain)
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
                AxisValueLabel(format: .dateTime.month(.narrow))
            }
        }
    }
}
