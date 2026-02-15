import SwiftUI
import Charts

/// Weekly summary chart showing exercise minutes and steps as a dual-tab mini chart.
struct WeeklySummaryChartView: View {
    let exerciseData: [ChartDataPoint]
    let stepsData: [ChartDataPoint]

    @State private var selectedTab: Tab = .exercise

    enum Tab: String, CaseIterable {
        case exercise = "Exercise"
        case steps = "Steps"
    }

    var body: some View {
        HeroCard(tintColor: DS.Color.activity) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("This Week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(summaryText)
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                    }

                    Spacer()

                    Picker("Metric", selection: $selectedTab) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }

                // Chart
                chart
                    .frame(height: 140)
                    .animation(DS.Animation.standard, value: selectedTab)
            }
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chart: some View {
        let data = selectedTab == .exercise ? exerciseData : stepsData
        let color = selectedTab == .exercise ? DS.Color.activity : DS.Color.steps

        Chart {
            ForEach(data) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                AxisGridLine()
            }
        }
    }

    // MARK: - Summary

    private var summaryText: String {
        switch selectedTab {
        case .exercise:
            let total = exerciseData.map(\.value).reduce(0, +)
            return "\(Int(total)) min"
        case .steps:
            let avg = stepsData.isEmpty ? 0 : stepsData.map(\.value).reduce(0, +) / Double(stepsData.count)
            return "\(Int(avg)) avg"
        }
    }
}
