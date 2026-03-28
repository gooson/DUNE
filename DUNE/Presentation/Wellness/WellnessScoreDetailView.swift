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
        static let posture = String(localized: "Posture")
        nonisolated(unsafe) static let calculationBullets: [LocalizedStringKey] = [
            "Final score = weighted average of Sleep(35%), Condition(30%), Body(20%), and Posture(15%).",
            "Sleep and Condition come from Apple Watch signals, then normalized to 0-100.",
            "Body score is derived from 7-day trend stability and direction changes.",
            "Posture score reflects your latest posture assessment result (0-100).",
            "If any component is missing, remaining weights are re-normalized before final scoring.",
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // 1. Score Hero
                scoreHero
                    .staggeredAppear(index: 0)

                // 2. Time-of-Day Card
                TimeOfDayCard(
                    currentAdjustment: wellnessScore.timeOfDayAdjustment,
                    baseScore: Double(wellnessScore.score) - wellnessScore.timeOfDayAdjustment
                )
                .staggeredAppear(index: 1)

                // 3. Period Picker
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)
                .staggeredAppear(index: 2)

                // 4. Chart Header
                ScoreDetailChartHeader(
                    visibleRangeLabel: viewModel.visibleRangeLabel,
                    showTrendLine: $viewModel.showTrendLine,
                    tintColor: wellnessScore.status.color
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
                    .staggeredAppear(index: 6)

                    SubScoreTrendChartView(
                        title: "Resting Heart Rate",
                        data: viewModel.rhrTrend,
                        color: DS.Color.heartRate,
                        unit: "bpm"
                    )
                    .staggeredAppear(index: 6)

                    SubScoreTrendChartView(
                        title: "Sleep Duration",
                        data: viewModel.sleepTrend,
                        color: DS.Color.sleep,
                        unit: "hrs",
                        fractionDigits: 1
                    )
                    .staggeredAppear(index: 6)
                }

                // 9. Component Weights
                ScoreCompositionCard(
                    title: "Score Composition",
                    components: [
                        .init(label: Labels.sleep, weight: "35%", score: wellnessScore.sleepScore, color: DS.Color.sleep),
                        .init(label: Labels.condition, weight: "30%", score: wellnessScore.conditionScore, color: DS.Color.hrv),
                        .init(label: Labels.body, weight: "20%", score: wellnessScore.bodyScore, color: DS.Color.body),
                        .init(label: Labels.posture, weight: "15%", score: wellnessScore.postureScore, color: DS.Color.posture),
                    ]
                )
                .staggeredAppear(index: 7)

                // 10. Contributors
                if let conditionScore, !conditionScore.contributions.isEmpty {
                    StandardCard {
                        ScoreContributorsView(contributions: conditionScore.contributions)
                    }
                    .staggeredAppear(index: 7)
                }

                // 11. Calculation Cards
                if let detail = conditionScore?.detail {
                    ConditionCalculationCard(detail: detail)
                        .staggeredAppear(index: 7)
                }

                if let bodyDetail = bodyScoreDetail {
                    BodyCalculationCard(detail: bodyDetail)
                        .staggeredAppear(index: 7)
                }

                // 12. Explainer
                CalculationMethodCard(
                    icon: "function",
                    title: "Calculation Method",
                    bullets: Labels.calculationBullets
                )
                .staggeredAppear(index: 7)
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
                .init(label: Labels.posture, value: wellnessScore.postureScore, color: DS.Color.posture),
            ]
        )
    }

    // MARK: - Helpers

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 360 : 250
    }
}
