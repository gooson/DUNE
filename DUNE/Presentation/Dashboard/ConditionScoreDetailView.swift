import SwiftUI

/// Detail view for the Condition Score.
/// Follows the canonical score detail layout:
/// Hero → Insight → Time-of-Day → Period Picker → Chart Header → DotLineChart
/// → Summary Stats → Highlights → Sub-Scores → Component Weights → Contributors
/// → Calculation Card → Explainer
struct ConditionScoreDetailView: View {
    let score: ConditionScore
    let scoreRefreshService: ScoreRefreshService?

    private enum Labels {
        static let scoreLabel = "CONDITION"
    }

    @State private var viewModel: ConditionScoreDetailViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(score: ConditionScore, scoreRefreshService: ScoreRefreshService? = nil) {
        self.score = score
        self.scoreRefreshService = scoreRefreshService
        _viewModel = State(initialValue: ConditionScoreDetailViewModel(scoreRefreshService: scoreRefreshService))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // 1. Hero + Insight + Contributors
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: DS.Spacing.xxl) {
                        scoreHero
                            .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            ConditionInsightSection(status: score.status)

                            if !score.contributions.isEmpty {
                                StandardCard {
                                    ScoreContributorsView(contributions: score.contributions)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    scoreHero
                    ConditionInsightSection(status: score.status)

                    if !score.contributions.isEmpty {
                        StandardCard {
                            ScoreContributorsView(contributions: score.contributions)
                        }
                    }
                }

                // 2. Time-of-Day Card
                if let detail = score.detail {
                    TimeOfDayCard(
                        currentAdjustment: detail.timeOfDayAdjustment,
                        baseScore: Double(score.score) - detail.timeOfDayAdjustment
                    )
                }

                // 3. Period Picker
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)

                // 4. Chart Header
                ScoreDetailChartHeader(
                    visibleRangeLabel: viewModel.visibleRangeLabel,
                    showTrendLine: $viewModel.showTrendLine,
                    tintColor: score.status.color
                )

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
                                tintColor: score.status.color,
                                trendLine: viewModel.trendLineData,
                                scrollDomain: viewModel.scrollDomain,
                                scrollPosition: $viewModel.scrollPosition
                            )
                            .frame(height: chartHeight)
                            .overlay {
                                ChartUITestSurface(
                                    identifier: "detail-chart-surface",
                                    label: "Condition Detail Chart",
                                    value: viewModel.visibleRangeLabel
                                )
                            }
                        }
                    }
                    .id(viewModel.selectedPeriod)
                    .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)

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
                } else {
                    if let summary = viewModel.summaryStats {
                        ScoreDetailSummaryStats(summary: summary)
                    }
                    if !viewModel.highlights.isEmpty {
                        ScoreDetailHighlights(highlights: viewModel.highlights)
                    }
                }

                // 8. Sub-Score Charts (HRV → RHR)
                if viewModel.selectedPeriod != .day {
                    SubScoreTrendChartView(
                        title: "HRV",
                        data: viewModel.hrvTrend,
                        color: DS.Color.hrv,
                        unit: "ms",
                        fractionDigits: 1
                    )

                    SubScoreTrendChartView(
                        title: "Resting Heart Rate",
                        data: viewModel.rhrTrend,
                        color: DS.Color.heartRate,
                        unit: "bpm"
                    )
                }

                // 9. Component Weights
                conditionComposition

                // 10. Calculation Card
                if let detail = score.detail {
                    ConditionCalculationCard(detail: detail)
                }

                // 11. Explainer
                StandardCard {
                    ConditionExplainerSection()
                }
            }
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .accessibilityIdentifier("condition-score-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Condition Score")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading && viewModel.chartData.isEmpty {
                ProgressView()
            }
        }
        .task {
            viewModel.configure(score: score)
            await viewModel.loadData()
        }
    }

    // MARK: - Subviews

    private var scoreHero: some View {
        DetailScoreHero(
            score: score.score,
            scoreLabel: Labels.scoreLabel,
            statusLabel: score.status.label,
            statusIcon: score.status.iconName,
            statusColor: score.status.color,
            guideMessage: score.narrativeMessage
        )
    }

    private var conditionComposition: some View {
        ScoreCompositionCard(
            title: "Score Components",
            components: [
                .init(
                    label: String(localized: "HRV (Z-Score)"),
                    weight: "70%",
                    score: score.detail.map { Int(max(0, min(100, $0.rawScore + $0.rhrAdjustment)).rounded()) },
                    color: DS.Color.hrv
                ),
                .init(
                    label: String(localized: "RHR Adjustment"),
                    weight: "30%",
                    score: score.detail.map { _ in score.score },
                    color: DS.Color.heartRate
                ),
            ]
        )
    }

    // MARK: - Helpers

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 360 : 250
    }
}
