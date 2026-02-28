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
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                ProgressRingView(
                    progress: Double(readiness.score) / 100.0,
                    ringColor: readiness.status.color,
                    lineWidth: isRegular ? 18 : 16,
                    size: isRegular ? 180 : 140,
                    useWarmGradient: true
                )

                VStack(spacing: 2) {
                    Text("\(readiness.score)")
                        .font(DS.Typography.heroScore)
                        .foregroundStyle(DS.Gradient.detailScore)
                        .contentTransition(.numericText())

                    Text("READINESS")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Color.sandMuted)
                        .tracking(1)
                }
            }

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: readiness.status.iconName)
                    .foregroundStyle(readiness.status.color)
                Text(readiness.status.label)
                    .font(.title3.weight(.semibold))

                if readiness.isCalibrating {
                    Text("Calibrating")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.quaternary))
                }
            }

            Text(readiness.status.guideMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Sub-score summary row
            HStack(spacing: DS.Spacing.lg) {
                subScoreBadge(label: "HRV", value: readiness.components.hrvScore, color: DS.Color.hrv)
                subScoreBadge(label: "RHR", value: readiness.components.rhrScore, color: DS.Color.heartRate)
                subScoreBadge(label: "Sleep", value: readiness.components.sleepScore, color: DS.Color.sleep)
                subScoreBadge(label: "Recovery", value: readiness.components.fatigueScore, color: DS.Color.activity)
                subScoreBadge(label: "Trend", value: readiness.components.trendBonus, color: DS.Color.fitness)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func subScoreBadge(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
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
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            Text("Track your workouts and wear Apple Watch to see your training readiness breakdown.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}
