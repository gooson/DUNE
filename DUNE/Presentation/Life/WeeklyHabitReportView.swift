import SwiftUI

struct WeeklyHabitReportView: View {
    let report: WeeklyHabitReport

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
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Weekly Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overview

    private var overviewCard: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("This Week")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(Int(report.overallCompletionRate * 100))%")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(rateColor(report.overallCompletionRate))

            Text("\(report.totalCompletions) of \(report.totalGoals) completed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Comparison

    private var comparisonCard: some View {
        HStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.xs) {
                Text("This Week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(report.overallCompletionRate * 100))%")
                    .font(.title2.bold())
                    .foregroundStyle(rateColor(report.overallCompletionRate))
            }

            Image(systemName: trendIcon)
                .font(.title)
                .foregroundStyle(trendColor)

            VStack(spacing: DS.Spacing.xs) {
                Text("Last Week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(report.previousWeekRate * 100))%")
                    .font(.title2.bold())
                    .foregroundStyle(rateColor(report.previousWeekRate))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Best Habits

    private var bestHabitsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label("Best Habits", systemImage: "star.fill")
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
            Label("Needs Improvement", systemImage: "arrow.up.right")
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

    private func habitRow(name: String, rate: Double) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
            Spacer()
            Text("\(Int(rate * 100))%")
                .font(.subheadline.bold())
                .foregroundStyle(rateColor(rate))
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
