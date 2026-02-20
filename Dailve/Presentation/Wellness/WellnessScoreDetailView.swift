import SwiftUI

/// Detail view for the Wellness Score.
/// Shows score ring, sub-score breakdown, condition contributors, and explainer.
struct WellnessScoreDetailView: View {
    let wellnessScore: WellnessScore
    let conditionScore: ConditionScore?

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: isRegular ? DS.Spacing.xl : DS.Spacing.lg) {
                scoreHero

                if isRegular {
                    iPadContent
                } else {
                    iPhoneContent
                }
            }
            .padding(isRegular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .navigationTitle("Wellness Score")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - iPhone Layout

    private var iPhoneContent: some View {
        Group {
            subScoreBreakdown

            if let condition = conditionScore, !condition.contributions.isEmpty {
                contributorsCard(condition.contributions)
            }

            StandardCard {
                explainerSection
            }
        }
    }

    // MARK: - iPad Layout

    private let iPadGridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: DS.Spacing.lg),
        GridItem(.flexible(), spacing: DS.Spacing.lg),
        GridItem(.flexible(), spacing: DS.Spacing.lg)
    ]

    private var iPadContent: some View {
        VStack(spacing: DS.Spacing.xl) {
            // 3-column sub-score cards
            LazyVGrid(columns: iPadGridColumns, spacing: DS.Spacing.lg) {
                subScoreCard(
                    label: "Sleep",
                    weight: 40,
                    score: wellnessScore.sleepScore,
                    color: DS.Color.sleep,
                    icon: "moon.zzz.fill",
                    description: "Sleep quality and duration from last night."
                )

                subScoreCard(
                    label: "Condition",
                    weight: 35,
                    score: wellnessScore.conditionScore,
                    color: DS.Color.hrv,
                    icon: "waveform.path.ecg",
                    description: "HRV and resting heart rate relative to your baseline."
                )

                subScoreCard(
                    label: "Body",
                    weight: 25,
                    score: wellnessScore.bodyScore,
                    color: DS.Color.body,
                    icon: "figure.stand",
                    description: "Weight and body composition trend over the past week."
                )
            }

            // Contributors + Explainer side-by-side
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                if let condition = conditionScore, !condition.contributions.isEmpty {
                    contributorsCard(condition.contributions)
                }

                StandardCard {
                    explainerSection
                }
            }
        }
    }

    // MARK: - Score Hero

    private var ringSize: CGFloat { isRegular ? 160 : 120 }
    private var ringLineWidth: CGFloat { isRegular ? 14 : 12 }

    private var scoreHero: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.lg) {
                HStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                    // Ring
                    ZStack {
                        ProgressRingView(
                            progress: Double(wellnessScore.score) / 100.0,
                            ringColor: wellnessScore.status.color,
                            lineWidth: ringLineWidth,
                            size: ringSize
                        )

                        VStack(spacing: DS.Spacing.xxs) {
                            Text("\(wellnessScore.score)")
                                .font(DS.Typography.heroScore)
                                .fontDesign(.rounded)

                            Text("WELLNESS")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .tracking(1)
                        }
                    }

                    // Status + Guide
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: wellnessScore.status.iconName)
                                .font(.title3)
                                .foregroundStyle(wellnessScore.status.color)

                            Text(wellnessScore.status.label)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Text(wellnessScore.guideMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Mini sub-score summary
                        HStack(spacing: DS.Spacing.lg) {
                            miniScore(label: "Sleep", value: wellnessScore.sleepScore, color: DS.Color.sleep)
                            miniScore(label: "Condition", value: wellnessScore.conditionScore, color: DS.Color.hrv)
                            miniScore(label: "Body", value: wellnessScore.bodyScore, color: DS.Color.body)
                        }
                        .padding(.top, DS.Spacing.xs)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wellness score \(wellnessScore.score), \(wellnessScore.status.label)")
    }

    private func miniScore(label: String, value: Int?, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value.map { "\($0)" } ?? "--")
                .font(.headline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(value != nil ? .primary : .quaternary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: 44)
    }

    // MARK: - Contributors Card

    private func contributorsCard(_ contributions: [ScoreContribution]) -> some View {
        StandardCard {
            ScoreContributorsView(contributions: contributions)
        }
    }

    // MARK: - Sub-Score Card (iPad individual)

    private func subScoreCard(
        label: String,
        weight: Int,
        score: Int?,
        color: Color,
        icon: String,
        description: String
    ) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(label)
                            .font(.headline)
                            .fontWeight(.medium)

                        Text("\(weight)% weight")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text(score.map { "\($0)" } ?? "--")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(score != nil ? .primary : .quaternary)
                }

                // Progress bar
                GeometryReader { geo in
                    let fraction = CGFloat(score ?? 0) / 100.0
                    Capsule()
                        .fill(color.opacity(0.15))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * fraction)
                        }
                }
                .frame(height: 8)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(weight) percent weight, score \(score.map { "\($0)" } ?? "no data")")
    }

    // MARK: - Sub-Score Breakdown (iPhone)

    private var subScoreBreakdown: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Score Breakdown")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                subScoreRow(
                    label: "Sleep",
                    weight: 40,
                    score: wellnessScore.sleepScore,
                    color: DS.Color.sleep,
                    icon: "moon.zzz.fill",
                    description: "Sleep quality and duration from last night."
                )

                Divider()

                subScoreRow(
                    label: "Condition",
                    weight: 35,
                    score: wellnessScore.conditionScore,
                    color: DS.Color.hrv,
                    icon: "waveform.path.ecg",
                    description: "HRV and resting heart rate relative to your baseline."
                )

                Divider()

                subScoreRow(
                    label: "Body",
                    weight: 25,
                    score: wellnessScore.bodyScore,
                    color: DS.Color.body,
                    icon: "figure.stand",
                    description: "Weight and body composition trend over the past week."
                )
            }
        }
    }

    private func subScoreRow(
        label: String,
        weight: Int,
        score: Int?,
        color: Color,
        icon: String,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(weight)%")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.1), in: Capsule())

                Spacer()

                Text(score.map { "\($0)" } ?? "--")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(score != nil ? .primary : .quaternary)
            }

            // Progress bar
            GeometryReader { geo in
                let fraction = CGFloat(score ?? 0) / 100.0
                Capsule()
                    .fill(color.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * fraction)
                    }
            }
            .frame(height: 6)

            Text(description)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(weight) percent weight, score \(score.map { "\($0)" } ?? "no data")")
    }

    // MARK: - Explainer

    private var explainerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.secondary)
                Text("How It Works")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                explainerItem(
                    "Your Wellness Score combines three key health dimensions into a single 0-100 score."
                )
                explainerItem(
                    "Sleep (40%): Based on sleep duration, stages, and efficiency from Apple Watch."
                )
                explainerItem(
                    "Condition (35%): Uses HRV trends and resting heart rate changes compared to your personal baseline."
                )
                explainerItem(
                    "Body (25%): Tracks weight and body composition stability over the past week."
                )
                explainerItem(
                    "Missing data is handled by redistributing weights among available scores."
                )
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
