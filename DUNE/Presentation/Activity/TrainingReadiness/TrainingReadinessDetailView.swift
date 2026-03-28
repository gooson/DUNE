import SwiftUI

/// Detail view for Training Readiness.
/// Follows the canonical score detail layout:
/// Hero → Time-of-Day → Period Picker → Chart Header → DotLineChart
/// → Summary Stats → Highlights → Sub-Scores → Component Weights
/// → Calculation Card → Explainer
struct TrainingReadinessDetailView: View {
    let readiness: TrainingReadiness?
    let scoreRefreshService: ScoreRefreshService?

    @State private var viewModel: TrainingReadinessDetailViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(readiness: TrainingReadiness?, scoreRefreshService: ScoreRefreshService? = nil) {
        self.readiness = readiness
        self.scoreRefreshService = scoreRefreshService
        _viewModel = State(initialValue: TrainingReadinessDetailViewModel(scoreRefreshService: scoreRefreshService))
    }

    private enum Labels {
        static let scoreLabel = "READINESS"
        static let hrv = String(localized: "HRV")
        static let rhr = String(localized: "RHR")
        static let sleep = String(localized: "Sleep")
        static let recovery = String(localized: "Recovery")
        static let trend = String(localized: "Trend")
        static let calibrating = String(localized: "Calibrating")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                if viewModel.isLoading && viewModel.chartData.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let readiness = viewModel.readiness {
                    // 1. Score Hero
                    scoreHero(readiness)
                        .staggeredAppear(index: 0)

                    // 2. Time-of-Day Card
                    TimeOfDayCard(
                        currentAdjustment: readiness.timeOfDayAdjustment,
                        baseScore: Double(readiness.score) - readiness.timeOfDayAdjustment
                    )
                    .staggeredAppear(index: 1)

                    // 3. Period Picker
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("training-readiness-period-picker")
                    .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)
                    .staggeredAppear(index: 2)

                    // 4. Chart Header
                    ScoreDetailChartHeader(
                        visibleRangeLabel: viewModel.visibleRangeLabel,
                        showTrendLine: $viewModel.showTrendLine,
                        tintColor: readiness.status.color
                    )
                    .staggeredAppear(index: 3)

                    // 5. Main Trend Chart (DotLineChartView)
                    StandardCard {
                        Group {
                            if viewModel.chartData.isEmpty && !viewModel.isLoading {
                                ScoreDetailEmptyState(chartHeight: chartHeight)
                            } else {
                                DotLineChartView(
                                    data: viewModel.chartData,
                                    baseline: 50,
                                    yAxisLabel: "Score",
                                    timePeriod: viewModel.selectedPeriod,
                                    tintColor: readiness.status.color,
                                    trendLine: viewModel.trendLineData,
                                    scrollDomain: viewModel.scrollDomain,
                                    scrollPosition: $viewModel.scrollPosition
                                )
                                .frame(height: chartHeight)
                                .accessibilityIdentifier("trainingreadiness-chart-trend")
                            }
                        }
                        .id(viewModel.selectedPeriod)
                        .transition(.opacity)
                    }
                    .accessibilityIdentifier("trainingreadiness-chart-trend")
                    .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)
                    .staggeredAppear(index: 4)

                    // 6. Summary Stats + 7. Highlights
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: DS.Spacing.lg) {
                            if let summary = viewModel.summaryStats {
                                ScoreDetailSummaryStats(summary: summary)
                                    .frame(maxWidth: .infinity)
                            }
                            if !viewModel.highlights.isEmpty {
                                ScoreDetailHighlights(highlights: viewModel.highlights)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .staggeredAppear(index: 5)
                    } else {
                        if let summary = viewModel.summaryStats {
                            ScoreDetailSummaryStats(summary: summary)
                                .staggeredAppear(index: 5)
                        }
                        if !viewModel.highlights.isEmpty {
                            ScoreDetailHighlights(highlights: viewModel.highlights)
                                .staggeredAppear(index: 5)
                        }
                    }

                    // 8. Sub-Score Charts (HRV → RHR → Sleep)
                    if viewModel.selectedPeriod != .day {
                        SubScoreTrendChartView(
                            title: "HRV",
                            data: viewModel.hrvTrend,
                            color: DS.Color.hrv,
                            unit: "ms"
                        )
                        .accessibilityIdentifier("training-readiness-subscore-hrv")
                        .staggeredAppear(index: 6)

                        SubScoreTrendChartView(
                            title: "Resting Heart Rate",
                            data: viewModel.rhrTrend,
                            color: DS.Color.heartRate,
                            unit: "bpm"
                        )
                        .accessibilityIdentifier("training-readiness-subscore-rhr")
                        .staggeredAppear(index: 6)

                        SubScoreTrendChartView(
                            title: "Sleep Duration",
                            data: viewModel.sleepTrend,
                            color: DS.Color.sleep,
                            unit: "hrs",
                            fractionDigits: 1
                        )
                        .accessibilityIdentifier("training-readiness-subscore-sleep")
                        .staggeredAppear(index: 6)
                    }

                    // 9. Component Weights
                    ScoreCompositionCard(
                        title: "Score Composition",
                        components: [
                            .init(label: String(localized: "HRV Variability"), weight: "30%", score: readiness.components.hrvScore, color: DS.Color.hrv),
                            .init(label: String(localized: "Sleep Quality"), weight: "25%", score: readiness.components.sleepScore, color: DS.Color.sleep),
                            .init(label: String(localized: "Resting Heart Rate"), weight: "20%", score: readiness.components.rhrScore, color: DS.Color.heartRate),
                            .init(label: String(localized: "Recovery Status"), weight: "15%", score: readiness.components.fatigueScore, color: DS.Color.activity),
                            .init(label: String(localized: "Trend Bonus"), weight: "10%", score: readiness.components.trendBonus, color: DS.Color.fitness),
                        ]
                    )
                    .staggeredAppear(index: 7)

                    // 10. Calculation Card
                    CalculationMethodCard(
                        icon: "function",
                        title: "Calculation Method",
                        bullets: calculationBullets(readiness)
                    )
                    .staggeredAppear(index: 7)
                } else {
                    ScoreDetailEmptyState(
                        icon: "figure.run",
                        title: "Need More Data",
                        message: "Track your workouts and wear Apple Watch to see your training readiness breakdown."
                    )
                }
            }
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .accessibilityIdentifier("activity-training-readiness-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Training Readiness")
        .task {
            viewModel.configure(readiness: readiness)
            await viewModel.loadData()
        }
    }

    // MARK: - Subviews

    private func scoreHero(_ readiness: TrainingReadiness) -> some View {
        DetailScoreHero(
            score: readiness.score,
            scoreLabel: Labels.scoreLabel,
            statusLabel: readiness.status.label,
            statusIcon: readiness.status.iconName,
            statusColor: readiness.status.color,
            guideMessage: readiness.status.guideMessage,
            subScores: [
                .init(label: Labels.hrv, value: readiness.components.hrvScore, color: DS.Color.hrv),
                .init(label: Labels.rhr, value: readiness.components.rhrScore, color: DS.Color.heartRate),
                .init(label: Labels.sleep, value: readiness.components.sleepScore, color: DS.Color.sleep),
                .init(label: Labels.recovery, value: readiness.components.fatigueScore, color: DS.Color.activity),
                .init(label: Labels.trend, value: readiness.components.trendBonus, color: DS.Color.fitness),
            ],
            badgeText: readiness.isCalibrating ? Labels.calibrating : nil
        )
    }

    private func calculationBullets(_ readiness: TrainingReadiness) -> [LocalizedStringKey] {
        var bullets: [LocalizedStringKey] = [
            "Final score = HRV(30%) + RHR(20%) + Sleep(25%) + Recovery(15%) + Trend(10%).",
            "Each component is normalized to 0-100 before weighting.",
            "HRV/RHR are compared against your personal baseline; positive trend increases score.",
        ]
        if readiness.isCalibrating {
            bullets.append("Calibration in progress: more recent data will stabilize the baseline.")
        }
        return bullets
    }

    // MARK: - Helpers

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 360 : 250
    }
}
