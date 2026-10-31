import SwiftUI

/// Detail view for Wellness Score.
/// Current score and its evidence, followed by the existing historical views and calculations.
struct WellnessScoreDetailView: View {
    let wellnessScore: WellnessScore
    let conditionScore: ConditionScore?
    let bodyScoreDetail: BodyScoreDetail?
    let scoreRefreshService: ScoreRefreshService?

    @State private var viewModel: WellnessScoreDetailViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .body) private var compactChartHeight: CGFloat = 250
    @ScaledMetric(relativeTo: .body) private var regularChartHeight: CGFloat = 360

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
                    baseScore: Double(wellnessScore.score) - wellnessScore.timeOfDayAdjustment,
                    usesAdaptiveLayout: true
                )
                .staggeredAppear(index: 1)

                trendCard
                    .staggeredAppear(index: 2)

                // 8. Sub-Score Charts (HRV → RHR → Sleep)
                if viewModel.selectedPeriod != .day {
                    SubScoreTrendChartView(
                        title: "HRV",
                        data: viewModel.hrvTrend,
                        color: DS.Color.hrv,
                        unit: "ms"
                    )
                    .accessibilityIdentifier("wellness-subscore-hrv")
                    .staggeredAppear(index: 6)

                    SubScoreTrendChartView(
                        title: "Resting Heart Rate",
                        data: viewModel.rhrTrend,
                        color: DS.Color.heartRate,
                        unit: "bpm"
                    )
                    .accessibilityIdentifier("wellness-subscore-rhr")
                    .staggeredAppear(index: 6)

                    SubScoreTrendChartView(
                        title: "Sleep Duration",
                        data: viewModel.sleepTrend,
                        color: DS.Color.sleep,
                        unit: "hrs",
                        fractionDigits: 1
                    )
                    .accessibilityIdentifier("wellness-subscore-sleep")
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
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
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
        H02WellnessDetailHero(score: wellnessScore)
    }

    private var trendCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)

                ScoreDetailChartHeader(
                    visibleRangeLabel: viewModel.visibleRangeLabel,
                    showTrendLine: $viewModel.showTrendLine,
                    tintColor: wellnessScore.status.color
                )

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

                if let summary = viewModel.summaryStats {
                    ScoreDetailSummaryStats(summary: summary)
                }
                if !viewModel.highlights.isEmpty {
                    ScoreDetailHighlights(highlights: viewModel.highlights)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wellness-detail-trend-card")
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)
    }

    private var chartHeight: CGFloat {
        sizeClass == .regular ? regularChartHeight : compactChartHeight
    }
}

/// H02 owns this presentation so shared score heroes keep their existing consumers.
private struct H02WellnessDetailHero: View {
    let score: WellnessScore

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: score.status.iconName)
                    .accessibilityLabel(score.status.label)
                    .accessibilityIdentifier("wellness-detail-status-icon")
                Text(verbatim: "WELLNESS")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.ink)
            .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                Text(score.score.formatted())
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .accessibilityIdentifier("wellness-detail-external-score")
                    .accessibilityLabel("Wellness score \(score.score), \(score.status.label)")
                status
            } else {
                HStack(alignment: .center, spacing: DS.Spacing.lg) {
                    CompactConditionRing(
                        score: score.score,
                        ringColor: palette.heroAccent,
                        highlightColor: palette.heroHighlight,
                        tipColor: score.status.color,
                        trackColor: palette.track,
                        textColor: palette.ink,
                        accessibilityLabel: "Wellness score \(score.score), \(score.status.label)",
                        accessibilityIdentifier: "wellness-detail-hero-ring"
                    )
                    status
                }
            }

            Text(score.evaluationDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundStyle(palette.muted)
                .accessibilityIdentifier("wellness-detail-evaluation-date")

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Score evidence")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Spacer(minLength: DS.Spacing.sm)
                    Text("Each out of 100")
                        .font(.caption2)
                        .foregroundStyle(palette.muted)
                }
                ForEach(evidence) { item in
                    evidenceRow(item)
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wellness-detail-hero")
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(score.status.label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.ink)
                .accessibilityIdentifier("wellness-detail-status")
            Text(score.narrativeMessage)
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("wellness-detail-narrative")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Evidence: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let icon: String
        let score: Int?
    }

    private var evidence: [Evidence] {
        [
            .init(id: "sleep", title: "Sleep", icon: "moon.fill", score: score.sleepScore),
            .init(id: "condition", title: "Condition", icon: "heart.fill", score: score.conditionScore),
            .init(id: "body", title: "Body", icon: "figure.stand", score: score.bodyScore),
            .init(id: "posture", title: "Posture", icon: "figure.stand", score: score.postureScore)
        ]
    }

    private func evidenceRow(_ item: Evidence) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: item.icon)
                    .font(.caption)
                    .foregroundStyle(palette.ink)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.subheadline)
                    .foregroundStyle(palette.ink)
                Spacer(minLength: DS.Spacing.sm)
                Text(item.score.map { $0.formatted() } ?? "—")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(item.score == nil ? palette.muted : palette.ink)
            }
            GeometryReader { geometry in
                Capsule()
                    .fill(palette.ink.opacity(0.16))
                    .overlay(alignment: .leading) {
                        if let value = item.score {
                            Capsule()
                                .fill(palette.heroAccent)
                                .frame(width: geometry.size.width * CGFloat(max(0, min(100, value))) / 100)
                        }
                    }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 52 : 38)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wellness-detail-component-\(item.id)")
    }
}
