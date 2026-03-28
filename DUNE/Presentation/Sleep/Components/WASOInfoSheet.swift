import SwiftUI

/// Explains what WASO means and how the score is calculated.
struct WASOInfoSheet: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                whatIsWASOSection
                howMeasuredSection
                scoringSection
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
                .foregroundStyle(DS.Color.sleep)

            Text(String(localized: "What is WASO?"))
                .font(.headline)

            Spacer()
        }
    }

    // MARK: - What is WASO

    private var whatIsWASOSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "moon.stars", title: String(localized: "Definition"))

            Text(String(localized: "WASO stands for Wake After Sleep Onset. It measures the total time you spend awake after initially falling asleep, until your final awakening."))
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - How Measured

    private var howMeasuredSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "applewatch", title: String(localized: "How It's Measured"))

            Text(String(localized: "Apple Watch detects awakenings during sleep using motion and heart rate sensors. Only awakenings lasting 5 minutes or longer are counted — brief stirrings are filtered out as normal sleep behavior."))
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Scoring

    private var scoringSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.bar", title: String(localized: "Scoring"))

            Text(String(localized: "The WASO Score (0–100) reflects how uninterrupted your sleep was. Less time awake means a higher score. This score contributes 15% to your overall Sleep Score."))
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Level Table

    private var levelTableSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "gauge.with.needle", title: String(localized: "Score Guide"))

            VStack(spacing: DS.Spacing.xs) {
                levelRow(label: Labels.excellent, range: "< 10 min", color: DS.Color.scoreGood)
                levelRow(label: Labels.good, range: "10–20 min", color: DS.Color.scoreFair)
                levelRow(label: Labels.fair, range: "20–30 min", color: .orange)
                levelRow(label: Labels.poor, range: "> 30 min", color: DS.Color.scoreWarning)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
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
        static let excellent = String(localized: "Excellent")
        static let good = String(localized: "Good")
        static let fair = String(localized: "Fair")
        static let poor = String(localized: "Poor")
    }
}
