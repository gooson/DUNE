import SwiftUI
import Charts

struct SleepView: View {
    @State private var viewModel = SleepViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Sleep Score Hero
                    sleepScoreCard

                    // Stage Breakdown
                    stageBreakdownCard

                    // Weekly Trend
                    weeklyTrendCard
                }
                .padding()
            }
            .navigationTitle("Sleep")
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Components

    private var sleepScoreCard: some View {
        VStack(spacing: 12) {
            Text("\(viewModel.sleepScore)")
                .font(.system(size: 56, weight: .bold, design: .rounded))

            Text(viewModel.totalSleepMinutes.hoursMinutesFormatted)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Efficiency: \(Int(viewModel.sleepEfficiency))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var stageBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages")
                .font(.headline)

            ForEach(viewModel.stageBreakdown, id: \.stage.rawValue) { item in
                HStack {
                    Circle()
                        .fill(item.stage.color)
                        .frame(width: 10, height: 10)
                    Text(item.stage.label)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(item.minutes)) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var weeklyTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Trend")
                .font(.headline)

            Chart(viewModel.weeklyData) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Hours", day.totalMinutes / 60)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let hours = value.as(Double.self) {
                            Text("\(Int(hours))h")
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 150)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

}

#Preview {
    SleepView()
}
