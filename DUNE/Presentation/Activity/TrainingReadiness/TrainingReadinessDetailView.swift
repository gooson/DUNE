import SwiftUI

/// Detail view for Training Readiness: score hero, 14-day trend, sub-score breakdowns.
struct TrainingReadinessDetailView: View {
    let readiness: TrainingReadiness?
    let hrvDailyAverages: [DailySample]
    let rhrDailyData: [DailySample]
    let sleepDailyData: [SleepDailySample]

    @State private var detailVM = TrainingReadinessDetailViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if detailVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let readiness = detailVM.readiness {
                    scoreHero(readiness)
                    ReadinessTrendChartView(data: detailVM.readinessTrend)
                    subScoreCharts
                    componentWeights(readiness)
                    calculationMethodSection(readiness)
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .background { DetailWaveBackground() }
        .navigationTitle("Training Readiness")
        .task {
            detailVM.loadData(
                readiness: readiness,
                hrvDailyAverages: hrvDailyAverages,
                rhrDailyData: rhrDailyData,
                sleepDailyData: sleepDailyData
            )
        }
    }

    // MARK: - Score Hero

    private func scoreHero(_ readiness: TrainingReadiness) -> some View {
        DetailScoreHero(
            score: readiness.score,
            scoreLabel: "READINESS",
            statusLabel: readiness.status.label,
            statusIcon: readiness.status.iconName,
            statusColor: readiness.status.color,
            guideMessage: readiness.status.guideMessage,
            subScores: [
                .init(label: "HRV", value: readiness.components.hrvScore, color: DS.Color.hrv),
                .init(label: "RHR", value: readiness.components.rhrScore, color: DS.Color.heartRate),
                .init(label: "Sleep", value: readiness.components.sleepScore, color: DS.Color.sleep),
                .init(label: "Recovery", value: readiness.components.fatigueScore, color: DS.Color.activity),
                .init(label: "Trend", value: readiness.components.trendBonus, color: DS.Color.fitness),
            ],
            badgeText: readiness.isCalibrating ? "Calibrating" : nil
        )
    }

    // MARK: - Sub-Score Charts

    private var subScoreCharts: some View {
        VStack(spacing: DS.Spacing.md) {
            SubScoreTrendChartView(
                title: "HRV",
                data: detailVM.hrvTrend,
                color: DS.Color.hrv,
                unit: "ms"
            )

            SubScoreTrendChartView(
                title: "Resting Heart Rate",
                data: detailVM.rhrTrend,
                color: DS.Color.heartRate,
                unit: "bpm"
            )

            SubScoreTrendChartView(
                title: "Sleep Duration",
                data: detailVM.sleepTrend,
                color: DS.Color.sleep,
                unit: "hrs",
                fractionDigits: 1
            )
        }
    }

    // MARK: - Component Weights

    private func componentWeights(_ readiness: TrainingReadiness) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Score Composition")
                .font(.subheadline.weight(.semibold))

            weightRow(label: "HRV Variability", weight: "30%", score: readiness.components.hrvScore, color: DS.Color.hrv)
            weightRow(label: "Sleep Quality", weight: "25%", score: readiness.components.sleepScore, color: DS.Color.sleep)
            weightRow(label: "Resting Heart Rate", weight: "20%", score: readiness.components.rhrScore, color: DS.Color.heartRate)
            weightRow(label: "Recovery Status", weight: "15%", score: readiness.components.fatigueScore, color: DS.Color.activity)
            weightRow(label: "Trend Bonus", weight: "10%", score: readiness.components.trendBonus, color: DS.Color.fitness)
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func weightRow(label: String, weight: String, score: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(weight)
                .font(.caption)
                .foregroundStyle(.tertiary)
            GeometryReader { geo in
                let fraction = CGFloat(score) / 100.0
                Capsule()
                    .fill(color.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * fraction)
                    }
            }
            .frame(width: 60, height: 6)
            .clipShape(Capsule())
            Text("\(score)")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - Calculation Method

    private func calculationMethodSection(_ readiness: TrainingReadiness) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "function")
                        .foregroundStyle(DS.Color.textSecondary)
                    Text("Calculation Method")
                        .font(.subheadline.weight(.semibold))
                }

                calculationMethodLine("Final score = HRV(30%) + RHR(20%) + Sleep(25%) + Recovery(15%) + Trend(10%).")
                calculationMethodLine("Each component is normalized to 0-100 before weighting.")
                calculationMethodLine("HRV/RHR are compared against your personal baseline; positive trend increases score.")

                if readiness.isCalibrating {
                    calculationMethodLine("Calibration in progress: more recent data will stabilize the baseline.")
                }
            }
        }
    }

    private func calculationMethodLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Circle()
                .fill(.tertiary)
                .frame(width: 4, height: 4)
                .padding(.top, 6)

            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "figure.run")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("Need More Data")
                .font(.headline)
                .foregroundStyle(DS.Color.textSecondary)
            Text("Track your workouts and wear Apple Watch to see your training readiness breakdown.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}
