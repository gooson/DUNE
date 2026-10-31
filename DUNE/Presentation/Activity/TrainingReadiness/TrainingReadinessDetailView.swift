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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(readiness: TrainingReadiness?, scoreRefreshService: ScoreRefreshService? = nil) {
        self.readiness = readiness
        self.scoreRefreshService = scoreRefreshService
        _viewModel = State(initialValue: TrainingReadinessDetailViewModel(scoreRefreshService: scoreRefreshService))
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
                        baseScore: Double(readiness.score) - readiness.timeOfDayAdjustment,
                        usesAdaptiveLayout: true
                    )
                    .staggeredAppear(index: 1)

                    // 3. Period, visible range, plot, and summary share one reading surface.
                    trendCard(readiness)
                        .staggeredAppear(index: 2)

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
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
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
        A02ReadinessDetailHero(readiness: readiness)
    }

    private func trendCard(_ readiness: TrainingReadiness) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("training-readiness-period-picker")
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)

                ScoreDetailChartHeader(
                    visibleRangeLabel: viewModel.visibleRangeLabel,
                    showTrendLine: $viewModel.showTrendLine,
                    tintColor: readiness.status.color
                )

                VStack(spacing: 0) {
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
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("trainingreadiness-chart-trend")

                if sizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
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
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("training-readiness-detail-trend-card")
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)
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

/// A02 owns its score presentation so the shared detail hero keeps its other consumers.
private struct A02ReadinessDetailHero: View {
    let readiness: TrainingReadiness

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: readiness.status.iconName)
                    .accessibilityLabel(readiness.status.label)
                    .accessibilityIdentifier("training-readiness-detail-status-icon")
                Text("Readiness")
                    .textCase(.uppercase)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.ink)
            .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                Text(readiness.score.formatted())
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .accessibilityLabel("Training readiness \(readiness.score), \(readiness.status.label)")
                    .accessibilityIdentifier("training-readiness-detail-external-score")
                status
            } else {
                HStack(alignment: .center, spacing: DS.Spacing.lg) {
                    CompactConditionRing(
                        score: readiness.score,
                        ringColor: palette.heroAccent,
                        highlightColor: palette.heroHighlight,
                        tipColor: readiness.status.color,
                        trackColor: palette.track,
                        textColor: palette.ink,
                        accessibilityLabel: "Training readiness \(readiness.score), \(readiness.status.label)",
                        accessibilityIdentifier: "training-readiness-detail-hero-ring"
                    )
                    status
                }
            }

            Text(readiness.evaluationDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundStyle(palette.muted)
                .accessibilityIdentifier("training-readiness-detail-evaluation-date")

            if readiness.isCalibrating {
                Text("Calibrating")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(palette.ink.opacity(0.12), in: Capsule())
                    .accessibilityIdentifier("training-readiness-detail-calibrating")
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Score Composition")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Spacer(minLength: DS.Spacing.sm)
                    Text("Each out of 100")
                        .font(.caption2)
                        .foregroundStyle(palette.muted)
                }
                ForEach(factors) { factor in
                    factorRow(factor)
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
        .accessibilityIdentifier("training-readiness-detail-hero")
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(readiness.status.label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.ink)
                .accessibilityIdentifier("training-readiness-detail-status")
            Text(readiness.status.guideMessage)
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Factor: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let icon: String
        let score: Int
        let weight: String
        let color: Color
    }

    private var factors: [Factor] {
        [
            .init(id: "hrv", title: "HRV Variability", icon: "waveform.path.ecg",
                  score: readiness.components.hrvScore, weight: "30%", color: DS.Color.hrv),
            .init(id: "sleep", title: "Sleep Quality", icon: "moon.zzz.fill",
                  score: readiness.components.sleepScore, weight: "25%", color: DS.Color.sleep),
            .init(id: "rhr", title: "Resting Heart Rate", icon: "heart.fill",
                  score: readiness.components.rhrScore, weight: "20%", color: DS.Color.heartRate),
            .init(id: "recovery", title: "Recovery Status", icon: "heart.text.clipboard",
                  score: readiness.components.fatigueScore, weight: "15%", color: DS.Color.activity),
            .init(id: "trend", title: "Trend Bonus", icon: "chart.line.uptrend.xyaxis",
                  score: readiness.components.trendBonus, weight: "10%", color: DS.Color.fitness)
        ]
    }

    private func factorRow(_ factor: Factor) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    factorTitle(factor)
                    HStack(spacing: DS.Spacing.sm) {
                        Text(factor.weight)
                            .font(.caption)
                            .foregroundStyle(palette.muted)
                        Spacer(minLength: DS.Spacing.sm)
                        factorScore(factor)
                    }
                }
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    factorTitle(factor)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(factor.weight)
                        .font(.caption)
                        .foregroundStyle(palette.muted)
                    factorScore(factor)
                }
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(palette.ink.opacity(0.16))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(factor.color)
                            .frame(width: geometry.size.width * CGFloat(max(0, min(100, factor.score))) / 100)
                    }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 62 : 42)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("training-readiness-detail-factor-\(factor.id)")
    }

    private func factorTitle(_ factor: Factor) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: factor.icon)
                .font(.caption)
                .foregroundStyle(palette.ink)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(factor.title)
                .font(.subheadline)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func factorScore(_ factor: Factor) -> some View {
        Text(factor.score.formatted())
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(palette.ink)
    }
}
