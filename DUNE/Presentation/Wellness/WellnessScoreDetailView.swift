import SwiftUI

/// Detail view for Wellness Score in the same visual pattern as Training Readiness detail.
struct WellnessScoreDetailView: View {
    let wellnessScore: WellnessScore
    let conditionScore: ConditionScore?
    let bodyScoreDetail: BodyScoreDetail?
    let sleepDailyData: [SleepDailySample]
    let hrvDailyData: [DailySample]
    let rhrDailyData: [DailySample]

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    private var sleepTrendData: [ChartDataPoint] {
        sleepDailyData
            .sorted { $0.date < $1.date }
            .map { ChartDataPoint(date: $0.date, value: $0.minutes / 60.0) }
    }

    private var hrvTrendData: [ChartDataPoint] {
        hrvDailyData
            .sorted { $0.date < $1.date }
            .map { ChartDataPoint(date: $0.date, value: $0.value) }
    }

    private var rhrTrendData: [ChartDataPoint] {
        rhrDailyData
            .sorted { $0.date < $1.date }
            .map { ChartDataPoint(date: $0.date, value: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                scoreHero
                subScoreCharts
                componentWeights

                if let conditionScore, !conditionScore.contributions.isEmpty {
                    contributorsCard(conditionScore.contributions)
                }

                if let detail = conditionScore?.detail {
                    ConditionCalculationCard(detail: detail)
                }

                if let bodyDetail = bodyScoreDetail {
                    BodyCalculationCard(detail: bodyDetail)
                }

                explainerCard
            }
            .padding()
        }
        .background { DetailWaveBackground() }
        .navigationTitle("Wellness Score")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Score Hero

    private var scoreHero: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                ProgressRingView(
                    progress: Double(wellnessScore.score) / 100.0,
                    ringColor: wellnessScore.status.color,
                    lineWidth: isRegular ? 18 : 16,
                    size: isRegular ? 180 : 140,
                    useWarmGradient: true
                )

                VStack(spacing: 2) {
                    Text("\(wellnessScore.score)")
                        .font(DS.Typography.heroScore)
                        .foregroundStyle(DS.Gradient.detailScore)
                        .contentTransition(.numericText())

                    Text("WELLNESS")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Color.sandMuted)
                        .tracking(1)
                }
            }

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: wellnessScore.status.iconName)
                    .foregroundStyle(wellnessScore.status.color)

                Text(wellnessScore.status.label)
                    .font(.title3.weight(.semibold))
            }

            Text(wellnessScore.guideMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: DS.Spacing.lg) {
                subScoreBadge(label: "Sleep", value: wellnessScore.sleepScore, color: DS.Color.sleep)
                subScoreBadge(label: "Condition", value: wellnessScore.conditionScore, color: DS.Color.hrv)
                subScoreBadge(label: "Body", value: wellnessScore.bodyScore, color: DS.Color.body)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wellness score \(wellnessScore.score), \(wellnessScore.status.label)")
    }

    private func subScoreBadge(label: String, value: Int?, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value.map { "\($0)" } ?? "--")
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(value != nil ? color : .secondary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Sub-score Charts

    private var subScoreCharts: some View {
        VStack(spacing: DS.Spacing.md) {
            SubScoreTrendChartView(
                title: "Sleep Duration",
                data: sleepTrendData,
                color: DS.Color.sleep,
                unit: "hrs",
                fractionDigits: 1
            )

            SubScoreTrendChartView(
                title: "HRV",
                data: hrvTrendData,
                color: DS.Color.hrv,
                unit: "ms"
            )

            SubScoreTrendChartView(
                title: "Resting Heart Rate",
                data: rhrTrendData,
                color: DS.Color.heartRate,
                unit: "bpm"
            )
        }
    }

    // MARK: - Component Weights

    private var componentWeights: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Score Composition")
                .font(.subheadline.weight(.semibold))

            weightRow(
                label: "Sleep Quality",
                weight: "40%",
                score: wellnessScore.sleepScore,
                color: DS.Color.sleep,
                fallbackLabel: "No sleep data"
            )

            weightRow(
                label: "Condition",
                weight: "35%",
                score: wellnessScore.conditionScore,
                color: DS.Color.hrv,
                fallbackLabel: "No condition data"
            )

            weightRow(
                label: "Body Trend",
                weight: "25%",
                score: wellnessScore.bodyScore,
                color: DS.Color.body,
                fallbackLabel: "No body data"
            )
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func weightRow(
        label: String,
        weight: String,
        score: Int?,
        color: Color,
        fallbackLabel: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            Text(weight)
                .font(.caption)
                .foregroundStyle(.tertiary)

            GeometryReader { geo in
                let resolved = max(0, min(score ?? 0, 100))
                let fraction = CGFloat(resolved) / 100.0

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

            Text(score.map { "\($0)" } ?? "--")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(score != nil ? .primary : .tertiary)
                .frame(width: 32, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(weight), \(score.map { "score \($0)" } ?? fallbackLabel)")
    }

    // MARK: - Contributors + Explainer

    private func contributorsCard(_ contributions: [ScoreContribution]) -> some View {
        StandardCard {
            ScoreContributorsView(contributions: contributions)
        }
    }

    // MARK: - Explainer

    private var explainerCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("Calculation Method")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                explainerItem("Final score = weighted average of Sleep(40%), Condition(35%), and Body(25%).")
                explainerItem("Sleep and Condition come from Apple Watch signals, then normalized to 0-100.")
                explainerItem("Body score is derived from 7-day trend stability and direction changes.")
                explainerItem("If any component is missing, remaining weights are re-normalized before final scoring.")
            }
        }
    }

    private func explainerItem(_ text: String) -> some View {
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
}
