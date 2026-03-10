import SwiftUI

/// Explains how sleep debt is calculated — shown from the gauge's info button.
struct SleepDebtInfoSheet: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                baselineSection
                calculationSection
                excessSleepSection
                Divider()
                levelTableSection
            }
            .padding(DS.Spacing.xl)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.body)

            Text("How Sleep Debt Works")
                .font(.headline)

            Spacer()
        }
    }

    // MARK: - Baseline

    private var baselineSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.line.flattrend.xyaxis", title: "Baseline")

            Text("Your personal baseline is the average sleep duration over the last 14 days. Days with no sleep data are excluded.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Calculation

    private var calculationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "calendar", title: "How It Adds Up")

            Text("Each day in the last 7 days is compared against your 14-day average. If you slept less than average, the shortfall is added to your debt.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Excess Sleep

    private var excessSleepSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "moon.zzz", title: "Excess Sleep")

            Text("Sleeping more than average on a given day does not reduce your accumulated debt. Each day's deficit is capped at zero — extra sleep won't cancel out previous shortfalls.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Level Table

    private var levelTableSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "gauge.with.needle", title: "Levels")

            VStack(spacing: DS.Spacing.xs) {
                levelRow(label: Labels.wellRested, range: "< 2h", color: DS.Color.scoreGood)
                levelRow(label: Labels.slightlyShort, range: "2–5h", color: DS.Color.scoreFair)
                levelRow(label: Labels.sleepDebt, range: "5–10h", color: DS.Color.scoreTired)
                levelRow(label: Labels.severeDebt, range: "> 10h", color: DS.Color.scoreWarning)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func levelRow(label: String, range: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(range)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Labels

    private enum Labels {
        static let wellRested = String(localized: "Well Rested")
        static let slightlyShort = String(localized: "Slightly Short")
        static let sleepDebt = String(localized: "Sleep Debt")
        static let severeDebt = String(localized: "Severe Debt")
    }
}
