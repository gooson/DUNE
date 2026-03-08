import SwiftUI
import Charts

/// Full detail view for Weekly/Monthly Workout Report — stats, summary, highlights, muscle breakdown.
struct WorkoutReportDetailView: View {
    let report: WorkoutReport?

    @Environment(\.appTheme) private var theme

    private enum Labels {
        static let statistics = String(localized: "Statistics")
        static let summary = String(localized: "Summary")
        static let highlights = String(localized: "Highlights")
        static let muscleBreakdown = String(localized: "Muscle Breakdown")
        static let sessions = String(localized: "Sessions")
        static let activeDays = String(localized: "Active Days")
        static let totalVolume = String(localized: "Total Volume")
        static let totalDuration = String(localized: "Total Duration")
        static let avgIntensity = String(localized: "Avg Intensity")
        static let volumeChange = String(localized: "Volume Change")
        static let noHighlights = String(localized: "No highlights this period")
    }

    var body: some View {
        ScrollView {
            if let report {
                VStack(spacing: DS.Spacing.lg) {
                    periodHeader(report)
                    statsGrid(report)
                    summarySection(report)
                    highlightsSection(report)
                    muscleBreakdownSection(report)
                }
                .padding()
            } else {
                emptyState
            }
        }
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Weekly Report")
        .accessibilityIdentifier("activity-weekly-report-detail-screen")
    }

    // MARK: - Period Header

    private func periodHeader(_ report: WorkoutReport) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(report.period.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Text(formatDateRange(start: report.startDate, end: report.endDate))
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Stats Grid

    private func statsGrid(_ report: WorkoutReport) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.statistics)
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
                statCell(value: "\(report.stats.totalSessions)", label: Labels.sessions)
                statCell(value: "\(report.stats.activeDays)", label: Labels.activeDays)
                statCell(value: formatVolume(report.stats.totalVolume), label: Labels.totalVolume)
                statCell(value: "\(report.stats.totalDuration) min", label: Labels.totalDuration)
                statCell(
                    value: String(format: "%.0f%%", report.stats.averageIntensity * 100),
                    label: Labels.avgIntensity
                )
                if let change = report.stats.volumeChangePercent {
                    statCell(
                        value: formatChange(change),
                        label: Labels.volumeChange,
                        valueColor: change >= 0 ? DS.Color.positive : DS.Color.negative
                    )
                }
            }
        }
    }

    private func statCell(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Summary Section

    private func summarySection(_ report: WorkoutReport) -> some View {
        Group {
            if let summary = report.formattedSummary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text(Labels.summary)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(DS.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }
            }
        }
    }

    // MARK: - Highlights Section

    private func highlightsSection(_ report: WorkoutReport) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.highlights)
                .font(.headline)
                .foregroundStyle(.primary)

            if report.highlights.isEmpty {
                Text(Labels.noHighlights)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            } else {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(report.highlights) { highlight in
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: highlightIcon(highlight.type))
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.activity)
                                .frame(width: 24)
                            Text(highlight.description)
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(DS.Spacing.sm)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                }
            }
        }
    }

    // MARK: - Muscle Breakdown

    private func muscleBreakdownSection(_ report: WorkoutReport) -> some View {
        Group {
            if !report.muscleBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text(Labels.muscleBreakdown)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    let maxVolume = report.muscleBreakdown.first?.volume ?? 1

                    VStack(spacing: DS.Spacing.xs) {
                        ForEach(report.muscleBreakdown) { stat in
                            HStack(spacing: DS.Spacing.sm) {
                                Text(stat.muscleGroup.displayName)
                                    .font(.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .frame(width: 80, alignment: .trailing)

                                GeometryReader { geo in
                                    let fraction = maxVolume > 0
                                        ? CGFloat(stat.volume) / CGFloat(maxVolume)
                                        : 0
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(DS.Color.activity.opacity(0.6))
                                        .frame(width: geo.size.width * fraction)
                                }
                                .frame(height: 16)

                                Text(formatVolume(stat.volume))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.primary)
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                    }
                    .padding(DS.Spacing.sm)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))kg"
    }

    private func formatChange(_ change: Double) -> String {
        let percent = Int(change * 100)
        return percent >= 0 ? "+\(percent)%" : "\(percent)%"
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start, to: end)
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

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("Complete a few workouts to see your weekly report.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
