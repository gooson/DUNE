import SwiftUI

struct WeeklyHabitReportView: View {
    let report: WeeklyHabitReport
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                overviewCard
                comparisonCard
                bestHabitsCard
                worstHabitsCard
            }
            .padding(DS.Spacing.md)
        }
        .accessibilityIdentifier("life-weekly-report-scroll")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Weekly Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overview

    private var overviewCard: some View {
        HeroCard(tintColor: DS.Color.tabLife) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Image(systemName: "calendar")
                        .accessibilityHidden(true)
                    Text("This Week")
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("life-weekly-report-period")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                Text("\(Int(report.overallCompletionRate * 100))%")
                    .font(DS.Typography.heroScore)
                    .foregroundStyle(rateColor(report.overallCompletionRate))
                    .accessibilityIdentifier("life-weekly-report-rate")
                Text("\(report.totalCompletions) of \(report.totalGoals) completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("life-weekly-report-total")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Comparison

    private var comparisonCard: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DS.Spacing.lg))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.lg))
        return StandardCard {
            layout {
                VStack(spacing: DS.Spacing.xs) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(report.overallCompletionRate * 100))%")
                        .font(.title2.bold())
                        .foregroundStyle(rateColor(report.overallCompletionRate))
                        .accessibilityIdentifier("life-weekly-report-comparison-current")
                }

                Image(systemName: trendIcon)
                    .font(.title)
                    .foregroundStyle(trendColor)
                    .accessibilityIdentifier("life-weekly-report-comparison-trend")

                VStack(spacing: DS.Spacing.xs) {
                    Text("Last Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(report.previousWeekRate * 100))%")
                        .font(.title2.bold())
                        .foregroundStyle(rateColor(report.previousWeekRate))
                        .accessibilityIdentifier("life-weekly-report-comparison-previous")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Best Habits

    private var bestHabitsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            reportHeading("Best Habits", systemImage: "star.fill", identifier: "life-weekly-report-best")
                .font(.headline)
                .foregroundStyle(DS.Color.positive)

            if report.bestHabits.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(report.bestHabits, id: \.name) { habit in
                    habitRow(name: habit.name, rate: habit.rate)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Worst Habits

    private var worstHabitsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            reportHeading("Needs Improvement", systemImage: "arrow.up.right", identifier: "life-weekly-report-improvement")
                .font(.headline)
                .foregroundStyle(DS.Color.negative)

            if report.worstHabits.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(report.worstHabits, id: \.name) { habit in
                    habitRow(name: habit.name, rate: habit.rate)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private func reportHeading(_ title: LocalizedStringKey, systemImage: String, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
        }
    }

    private func habitRow(name: String, rate: Double) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xxs))
            : AnyLayout(HStackLayout())
        return layout {
            Text(name)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Text("\(Int(rate * 100))%")
                .font(.subheadline.bold())
                .foregroundStyle(rateColor(rate))
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, DS.Spacing.xxs)
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate >= 0.8 { return DS.Color.positive }
        if rate >= 0.5 { return DS.Color.tabLife }
        return DS.Color.negative
    }

    private var trendIcon: String {
        if report.overallCompletionRate > report.previousWeekRate { return "arrow.up.circle.fill" }
        if report.overallCompletionRate < report.previousWeekRate { return "arrow.down.circle.fill" }
        return "equal.circle.fill"
    }

    private var trendColor: Color {
        if report.overallCompletionRate > report.previousWeekRate { return DS.Color.positive }
        if report.overallCompletionRate < report.previousWeekRate { return DS.Color.negative }
        return .secondary
    }
}
