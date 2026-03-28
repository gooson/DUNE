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

            Text("What is WASO?")
                .font(.headline)

            Spacer()
        }
    }

    // MARK: - What is WASO

    private var whatIsWASOSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "moon.stars", title: "Definition")

            Text("WASO stands for Wake After Sleep Onset. It measures the total time you spend awake after initially falling asleep, until your final awakening.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - How Measured

    private var howMeasuredSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "applewatch", title: "How It's Measured")

            Text("Apple Watch detects awakenings during sleep using motion and heart rate sensors. Only awakenings lasting 5 minutes or longer are counted — brief stirrings are filtered out as normal sleep behavior.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Scoring

    private var scoringSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.bar", title: "Scoring")

            Text("The WASO Score (0–100) reflects how uninterrupted your sleep was. Less time awake means a higher score. This score contributes 15% to your overall Sleep Score.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Level Table

    private var levelTableSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "gauge.with.needle", title: "Score Guide")

            VStack(spacing: DS.Spacing.xs) {
                levelRow(label: "Excellent", range: "< 10 min", color: DS.Color.scoreGood)
                levelRow(label: "Good", range: "10–20 min", color: DS.Color.scoreFair)
                levelRow(label: "Fair", range: "20–30 min", color: .orange)
                levelRow(label: "Poor", range: "> 30 min", color: DS.Color.scoreWarning)
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

    private func levelRow(label: LocalizedStringKey, range: String, color: Color) -> some View {
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
}
