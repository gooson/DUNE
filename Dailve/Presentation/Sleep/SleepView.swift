import SwiftUI
import Charts

struct SleepView: View {
    @State private var viewModel = SleepViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.weeklyData.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.weeklyData.isEmpty && viewModel.sleepScore == 0 && !viewModel.isLoading {
                EmptyStateView(
                    icon: "moon.zzz.fill",
                    title: "No Sleep Data",
                    message: "Wear Apple Watch to bed to automatically track your sleep stages and quality."
                )
            } else {
                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        if viewModel.isShowingHistoricalData, let date = viewModel.latestSleepDate {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                Text("Showing data from \(date, style: .date)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }

                        sleepScoreCard
                        stageBreakdownCard
                        weeklyTrendCard
                    }
                    .padding()
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
        .navigationTitle("Sleep")
    }

    // MARK: - Components

    private var sleepScoreCard: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.md) {
                Text("\(viewModel.sleepScore)")
                    .font(DS.Typography.heroScore)
                    .foregroundStyle(DS.Color.sleep)

                Text(viewModel.totalSleepMinutes.hoursMinutesFormatted)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Efficiency: \(Int(viewModel.sleepEfficiency))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var stageBreakdownCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Sleep Stages")
                    .font(.headline)

                // Horizontal stacked bar
                let totalMinutes = viewModel.stageBreakdown.map(\.minutes).reduce(0, +)
                if totalMinutes > 0 {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(viewModel.stageBreakdown.filter { $0.minutes > 0 }, id: \.stage.rawValue) { item in
                                let fraction = item.minutes / totalMinutes
                                RoundedRectangle(cornerRadius: DS.Radius.sm / 2)
                                    .fill(item.stage.color.gradient)
                                    .frame(width: max(geo.size.width * fraction - 2, 4))
                            }
                        }
                    }
                    .frame(height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }

                // Legend
                HStack(spacing: DS.Spacing.lg) {
                    ForEach(viewModel.stageBreakdown, id: \.stage.rawValue) { item in
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(item.stage.color)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.stage.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(item.minutes))m")
                                    .font(.caption.weight(.medium))
                            }
                        }
                    }
                }
            }
        }
    }

    private var weeklyTrendCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Weekly Trend")
                    .font(.headline)

                Chart(viewModel.weeklyData) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Hours", day.totalMinutes / 60)
                    )
                    .foregroundStyle(DS.Color.sleep.gradient)
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
        }
    }

}

#Preview {
    SleepView()
}
