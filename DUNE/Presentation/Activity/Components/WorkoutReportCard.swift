import SwiftUI

/// Displays a weekly or monthly report without inventing a previous-period comparison.
struct WorkoutReportCard: View {
    let report: WorkoutReport?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let report {
            filledContent(report)
        } else {
            emptyState
        }
    }

    private func filledContent(_ report: WorkoutReport) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(report.period.displayName)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 0) {
                    Text(report.startDate, format: .dateTime.month(.abbreviated).day())
                    Text(verbatim: "–")
                    Text(report.endDate, format: .dateTime.month(.abbreviated).day())
                }
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

                spotlight(report.stats)

                ActivityMetricsLayout(horizontalSpacing: DS.Spacing.sm, verticalSpacing: DS.Spacing.md, alignment: .top) {
                    keyStats(report.stats)
                }

                if let summary = report.formattedSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !report.muscleBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Primary Muscles")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: DS.Spacing.xs) {
                                muscleChips(report)
                            }
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                muscleChips(report)
                            }
                        }
                    }
                }

                let topHighlights = Array(report.highlights.prefix(2))
                if !topHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(topHighlights) { highlight in
                            Label(highlight.description, systemImage: highlightIcon(highlight.type))
                                .font(.caption)
                                .foregroundStyle(DS.Color.desertBronze)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func spotlight(_ stats: WorkoutReport.Stats) -> some View {
        ActivityMetricsLayout(horizontalSpacing: DS.Spacing.lg, verticalSpacing: DS.Spacing.md, alignment: .center) {
            spotlightContents(stats)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.activityCardio.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Color.activityCardio.opacity(0.35), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func spotlightContents(_ stats: WorkoutReport.Stats) -> some View {
        if let change = stats.volumeChangePercent {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Label("Strength Volume Change", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                Text(formatChange(change))
                    .font(DS.Typography.heroScore)
                    .foregroundStyle(DS.Color.desertBronze)
                    .monospacedDigit()
            }
        }
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Period Strength Volume")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(stats.totalVolume >= 0.01 ? stats.totalVolume.formattedWithSeparator() : "—")
                    .accessibilityIdentifier("activity-report-volume-value")
                    .font(DS.Typography.cardScore)
                    .monospacedDigit()
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func keyStats(_ stats: WorkoutReport.Stats) -> some View {
        statItem(value: stats.totalSessions.formatted(), label: "Sessions")
        statItem(value: stats.activeDays.formatted(), label: "Days")
        statItem(value: stats.totalDuration.formatted(), label: "Total Minutes")
    }

    private func statItem(value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func muscleChips(_ report: WorkoutReport) -> some View {
        ForEach(report.muscleBreakdown.prefix(3)) { stat in
            Text(stat.muscleGroup.displayName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Color.activity.opacity(0.10), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    private var emptyState: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("Complete a few workouts to see your weekly report.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    private func formatChange(_ change: Double) -> String {
        let percent = Int((change * 100).rounded())
        return "\(percent > 0 ? "+" : "")\(percent)%"
    }

    private func highlightIcon(_ type: WorkoutReport.HighlightType) -> String {
        switch type {
        case .personalRecord: "trophy.fill"
        case .streak: "flame.fill"
        case .volumeIncrease: "chart.line.uptrend.xyaxis"
        case .consistency: "calendar.badge.checkmark"
        case .newExercise: "star.fill"
        }
    }
}
