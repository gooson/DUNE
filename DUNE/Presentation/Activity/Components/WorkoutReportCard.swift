import SwiftUI

/// Displays a weekly/monthly workout summary with key stats and highlights.
struct WorkoutReportCard: View {
    let report: WorkoutReport?

    @Environment(\.appTheme) private var theme

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
                // Period label + stats overview
                HStack {
                    Text(report.period.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Key stats row
                HStack(spacing: DS.Spacing.lg) {
                    statItem(
                        value: "\(report.stats.totalSessions)",
                        label: String(localized: "Sessions")
                    )
                    statItem(
                        value: "\(report.stats.activeDays)",
                        label: String(localized: "Days")
                    )
                    statItem(
                        value: formatVolume(report.stats.totalVolume),
                        label: String(localized: "Volume")
                    )
                    if let change = report.stats.volumeChangePercent {
                        statItem(
                            value: formatChange(change),
                            label: String(localized: "vs Last"),
                            color: change >= 0 ? DS.Color.positive : DS.Color.negative
                        )
                    }
                }

                // Top muscle groups (max 3)
                if !report.muscleBreakdown.isEmpty {
                    let topMuscles = Array(report.muscleBreakdown.prefix(3))
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(topMuscles) { stat in
                            HStack(spacing: DS.Spacing.xxs) {
                                Circle()
                                    .fill(DS.Color.activity.opacity(0.6))
                                    .frame(width: 6, height: 6)
                                Text(stat.muscleGroup.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }

                // Summary text (from Foundation Models or template)
                if let summary = report.formattedSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .lineLimit(3)
                }

                // Highlights (max 2)
                let topHighlights = Array(report.highlights.prefix(2))
                if !topHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        ForEach(topHighlights) { highlight in
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: highlightIcon(highlight.type))
                                    .font(.caption2)
                                    .foregroundStyle(DS.Color.activity)
                                    .frame(width: 16)
                                Text(highlight.description)
                                    .font(.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
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

    // MARK: - Helpers

    private func statItem(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.0fk", volume / 1000)
        }
        return "\(Int(volume))kg"
    }

    private func formatChange(_ change: Double) -> String {
        let percent = Int(change * 100)
        return percent >= 0 ? "+\(percent)%" : "\(percent)%"
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
