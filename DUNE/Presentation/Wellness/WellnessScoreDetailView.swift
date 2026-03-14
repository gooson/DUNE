import SwiftUI

/// Detail view for Wellness Score.
/// Follows the canonical score detail layout:
/// Hero → Time-of-Day → Period Picker → Chart Header → DotLineChart
/// → Summary Stats → Highlights → Sub-Scores → Component Weights
/// → Contributors → Calculation Cards → Explainer
struct WellnessScoreDetailView: View {
    let wellnessScore: WellnessScore
    let conditionScore: ConditionScore?
    let bodyScoreDetail: BodyScoreDetail?
    let scoreRefreshService: ScoreRefreshService?

    @State private var viewModel: WellnessScoreDetailViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(
        wellnessScore: WellnessScore,
        conditionScore: ConditionScore?,
        bodyScoreDetail: BodyScoreDetail?,
        scoreRefreshService: ScoreRefreshService? = nil
    ) {
        self.wellnessScore = wellnessScore
        self.conditionScore = conditionScore
        self.bodyScoreDetail = bodyScoreDetail
        self.scoreRefreshService = scoreRefreshService
        _viewModel = State(initialValue: WellnessScoreDetailViewModel(scoreRefreshService: scoreRefreshService))
    }

    private enum Labels {
        static let scoreLabel = "WELLNESS"
        static let sleep = String(localized: "Sleep")
        static let condition = String(localized: "Condition")
        static let body = String(localized: "Body")
        nonisolated(unsafe) static let calculationBullets: [LocalizedStringKey] = [
            "Final score = weighted average of Sleep(40%), Condition(35%), and Body(25%).",
            "Sleep and Condition come from Apple Watch signals, then normalized to 0-100.",
            "Body score is derived from 7-day trend stability and direction changes.",
            "If any component is missing, remaining weights are re-normalized before final scoring.",
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // 1. Score Hero
                scoreHero

                // 2. Time-of-Day Card
                TimeOfDayCard(
                    currentAdjustment: wellnessScore.timeOfDayAdjustment,
                    baseScore: Double(wellnessScore.score) - wellnessScore.timeOfDayAdjustment
                )

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
                    tintColor: wellnessScore.status.color
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
                                tintColor: wellnessScore.status.color,
                                trendLine: viewModel.trendLineData,
                                scrollDomain: viewModel.scrollDomain,
                                scrollPosition: $viewModel.scrollPosition
                            )
                            .frame(height: chartHeight)
                            .accessibilityIdentifier("wellness-chart-trend")
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

                // 8. Sub-Score Charts (HRV → RHR → Sleep)
                if viewModel.selectedPeriod != .day {
                    SubScoreTrendChartView(
                        title: "HRV",
                        data: viewModel.hrvTrend,
                        color: DS.Color.hrv,
                        unit: "ms"
                    )

                    SubScoreTrendChartView(
                        title: "Resting Heart Rate",
                        data: viewModel.rhrTrend,
                        color: DS.Color.heartRate,
                        unit: "bpm"
                    )

                    SubScoreTrendChartView(
                        title: "Sleep Duration",
                        data: viewModel.sleepTrend,
                        color: DS.Color.sleep,
                        unit: "hrs",
                        fractionDigits: 1
                    )
                }

                // 9. Component Weights
                ScoreCompositionCard(
                    title: "Score Composition",
                    components: [
                        .init(label: Labels.sleep, weight: "40%", score: wellnessScore.sleepScore, color: DS.Color.sleep),
                        .init(label: Labels.condition, weight: "35%", score: wellnessScore.conditionScore, color: DS.Color.hrv),
                        .init(label: Labels.body, weight: "25%", score: wellnessScore.bodyScore, color: DS.Color.body),
                    ]
                )

                // 10. Contributors
                if let conditionScore, !conditionScore.contributions.isEmpty {
                    StandardCard {
                        ScoreContributorsView(contributions: conditionScore.contributions)
                    }
                }

                // 11. Calculation Cards
                if let detail = conditionScore?.detail {
                    ConditionCalculationCard(detail: detail)
                }

                if let bodyDetail = bodyScoreDetail {
                    BodyCalculationCard(detail: bodyDetail)
                }

                // 12. Explainer
                CalculationMethodCard(
                    icon: "function",
                    title: "Calculation Method",
                    bullets: Labels.calculationBullets
                )
            }
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .accessibilityIdentifier("wellness-score-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Wellness Score")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading && viewModel.chartData.isEmpty {
                ProgressView()
            }
        }
        .task {
            viewModel.configure(
                wellnessScore: wellnessScore,
                conditionScore: conditionScore,
                bodyScoreDetail: bodyScoreDetail
            )
            await viewModel.loadData()
        }
    }

    // MARK: - Subviews

    private var scoreHero: some View {
        DetailScoreHero(
            score: wellnessScore.score,
            scoreLabel: Labels.scoreLabel,
            statusLabel: wellnessScore.status.label,
            statusIcon: wellnessScore.status.iconName,
            statusColor: wellnessScore.status.color,
            guideMessage: wellnessScore.guideMessage,
            subScores: [
                .init(label: Labels.sleep, value: wellnessScore.sleepScore, color: DS.Color.sleep),
                .init(label: Labels.condition, value: wellnessScore.conditionScore, color: DS.Color.hrv),
                .init(label: Labels.body, value: wellnessScore.bodyScore, color: DS.Color.body),
            ]
        )
    }

    // MARK: - Helpers

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 360 : 250
    }
}
