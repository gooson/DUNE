import SwiftUI

/// The report's measured rates remain visible before opening its full detail.
struct WeeklyHabitSummaryCard: View {
    let report: WeeklyHabitReport

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Label("Weekly Report", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)

                Text(report.weekStart.formatted(.dateTime.month(.abbreviated).day()) + " – "
                     + report.weekEnd.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                rateRow("This Week", rate: report.overallCompletionRate, identifier: "life-weekly-current-rate")
                rateRow("Last Week", rate: report.previousWeekRate, identifier: "life-weekly-previous-rate")

                Text("\(report.totalCompletions) of \(report.totalGoals) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let best = report.bestHabits.first {
                    habitRow("Best Habits", name: best.name, icon: "star.fill")
                }
                if let next = report.worstHabits.first {
                    habitRow("Needs Improvement", name: next.name, icon: "arrow.up.right")
                }
                Label("View Weekly Report", systemImage: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Color.tabLife)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("life-weekly-report-summary")
    }

    private func rateRow(_ title: LocalizedStringKey, rate: Double, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.Spacing.sm)
                Text(rate.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .accessibilityIdentifier(identifier)
            }
            .font(.caption.weight(.semibold))
            ProgressView(value: min(max(rate, 0), 1))
                .tint(DS.Color.tabLife)
                .accessibilityHidden(true)
        }
    }

    private func habitRow(_ title: LocalizedStringKey, name: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(name)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    WeeklyHabitSummaryCard(report: .init(
        weekStart: .now, weekEnd: .now, overallCompletionRate: 0.76,
        previousWeekRate: 0.67, totalCompletions: 16, totalGoals: 21,
        bestHabits: [("Stretch", 1)], worstHabits: [("Reading", 0.57)], longestStreak: nil
    ))
    .padding()
}
