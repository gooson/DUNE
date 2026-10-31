import SwiftUI

/// Full detail view for Weekly/Monthly Workout Report — stats, summary, highlights, muscle breakdown.
struct WorkoutReportDetailView: View {
    let report: WorkoutReport?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    private enum Labels {
        static let statistics = String(localized: "Statistics")
        static let summary = String(localized: "Summary")
        static let highlights = String(localized: "Highlights")
        static let muscleBreakdown = String(localized: "Muscle Breakdown")
        static let noHighlights = String(localized: "No highlights this period")
    }

    var body: some View {
        ScrollView {
            if let report {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    reportHero(report)
                    statisticsSection(report)
                    summarySection(report)
                    highlightsSection(report)
                    muscleBreakdownSection(report)
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                emptyState
            }
        }
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Weekly Report")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("activity-weekly-report-detail-screen")
    }

    // MARK: - Report Hero

    private func reportHero(_ report: WorkoutReport) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                heroIcon("doc.text")
                Text(report.period.displayName)
                    .font(.headline)
            }
            .foregroundStyle(palette.ink)
            .accessibilityAddTraits(.isHeader)

            Text(formatDateRange(start: report.startDate, end: report.endDate))
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .accessibilityIdentifier("activity-weekly-report-date")

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    heroIcon("dumbbell.fill")
                    Text("Total Volume")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(palette.muted)
                Text(formatVolume(report.stats.totalVolume))
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .accessibilityIdentifier("activity-weekly-report-volume")
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: DS.Spacing.md) {
                    heroMetric("\(report.stats.totalSessions)", label: "Sessions", icon: "figure.strengthtraining.traditional",
                               identifier: "activity-weekly-report-sessions")
                    heroMetric("\(report.stats.activeDays)", label: "Active Days", icon: "calendar",
                               identifier: "activity-weekly-report-active-days")
                    heroMetric("\(report.stats.totalDuration) min", label: "Total Duration", icon: "clock",
                               identifier: "activity-weekly-report-duration")
                }
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    heroMetric("\(report.stats.totalSessions)", label: "Sessions", icon: "figure.strengthtraining.traditional",
                               identifier: "activity-weekly-report-sessions")
                    heroMetric("\(report.stats.activeDays)", label: "Active Days", icon: "calendar",
                               identifier: "activity-weekly-report-active-days")
                    heroMetric("\(report.stats.totalDuration) min", label: "Total Duration", icon: "clock",
                               identifier: "activity-weekly-report-duration")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-weekly-report-hero")
    }

    private func heroMetric(_ value: String, label: LocalizedStringKey, icon: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                heroIcon(icon)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(palette.muted)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(palette.ink)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Spacing.sm)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
        }
    }

    private func heroIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(dynamicTypeSize.isAccessibilitySize ? .system(size: 16) : .subheadline)
            .frame(width: 26)
            .clipped()
            .accessibilityHidden(true)
    }

    // MARK: - Statistics

    private func statisticsSection(_ report: WorkoutReport) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.statistics)
                .font(.headline)
                .foregroundStyle(.primary)

            statisticRow(value: "\(Int(report.stats.averageIntensity * 100))%",
                         label: "Avg Intensity", icon: "gauge.medium",
                         identifier: "activity-weekly-report-intensity")
            if let change = report.stats.volumeChangePercent {
                statisticRow(value: formatChange(change), label: "Volume Change",
                             icon: "chart.line.uptrend.xyaxis",
                             valueColor: change >= 0 ? DS.Color.positive : DS.Color.negative,
                             identifier: "activity-weekly-report-change")
            }
        }
    }

    private func statisticRow(
        value: String,
        label: LocalizedStringKey,
        icon: String,
        valueColor: Color = .primary,
        identifier: String
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    statisticLabel(label, icon: icon)
                    Text(value)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(valueColor)
                        .accessibilityIdentifier(identifier)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                    statisticLabel(label, icon: icon)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(value)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(valueColor)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier(identifier)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func statisticLabel(_ label: LocalizedStringKey, icon: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(dynamicTypeSize.isAccessibilitySize ? .system(size: 16) : .subheadline)
                .frame(width: 26)
                .clipped()
                .foregroundStyle(DS.Color.activity)
                .accessibilityHidden(true)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Summary and Highlights

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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.md)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        .accessibilityIdentifier("activity-weekly-report-summary")
                }
            }
        }
    }

    private func highlightsSection(_ report: WorkoutReport) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Labels.highlights)
                .font(.headline)
                .foregroundStyle(.primary)

            if report.highlights.isEmpty {
                Text(Labels.noHighlights)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            } else {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(report.highlights) { highlight in
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            Image(systemName: highlightIcon(highlight.type))
                                .font(dynamicTypeSize.isAccessibilitySize ? .system(size: 16) : .subheadline)
                                .foregroundStyle(DS.Color.activity)
                                .frame(width: 26)
                                .clipped()
                                .accessibilityHidden(true)
                            Text(highlight.description)
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("activity-weekly-report-highlight")
                        }
                        .padding(DS.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                    let maxVolume = report.muscleBreakdown.map(\.volume).max() ?? 1

                    VStack(spacing: DS.Spacing.md) {
                        ForEach(report.muscleBreakdown) { stat in
                            VStack(spacing: DS.Spacing.xs) {
                                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                                    Text(stat.muscleGroup.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(DS.Color.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(formatVolume(stat.volume))
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(.primary)
                                        .accessibilityIdentifier("activity-weekly-report-muscle-volume")
                                }
                                GeometryReader { geo in
                                    let fraction = maxVolume > 0
                                        ? CGFloat(stat.volume) / CGFloat(maxVolume)
                                        : 0
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(DS.Color.activity.opacity(0.6))
                                        .frame(width: geo.size.width * fraction)
                                }
                                .frame(height: 8)
                                .clipped()
                                .accessibilityHidden(true)
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }
            }
        }
    }

    // MARK: - Source Formatting

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            let whole = Int(volume / 1000)
            let tenth = Int(volume / 100) % 10
            return "\(whole).\(tenth)k"
        }
        return "\(Int(volume))kg"
    }

    private func formatChange(_ change: Double) -> String {
        let percent = Int(change * 100)
        return percent >= 0 ? "+\(percent)%" : "\(percent)%"
    }

    private enum Cache {
        static let dateIntervalFormatter: DateIntervalFormatter = {
            let f = DateIntervalFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f
        }()
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        Cache.dateIntervalFormatter.string(from: start, to: end)
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
