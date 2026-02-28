import SwiftUI

/// Explains how exercise mix (frequency distribution) is analyzed.
struct ExerciseMixInfoSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                measurementSection
                balanceSection
                tipsSection
            }
            .padding(DS.Spacing.xl)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Exercise Mix")
                    .font(.headline)
                Text("Exercise Mix")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "lightbulb.fill", title: "Overview")
            Text("Analyzes which exercises you perform and how often. Check the balance of your exercise mix and discover underworked areas.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "chart.bar.fill", title: "How It's Measured")
            InfoSheetHelpers.BulletPoint(text: "Tallies how many times each exercise was performed across all records")
            InfoSheetHelpers.BulletPoint(text: "Shows relative frequency as a percentage (%)")
            InfoSheetHelpers.BulletPoint(text: "Sorted by most frequently performed exercises")
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "arrow.left.arrow.right", title: "Balanced Composition")
            InfoSheetHelpers.BulletPoint(text: "A push/pull/legs/core balance is recommended")
            InfoSheetHelpers.BulletPoint(text: "Over-reliance on certain exercises increases muscle imbalance and injury risk")
            InfoSheetHelpers.BulletPoint(text: "Aim for balanced full-body development with varied exercise patterns")
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "lightbulb.max.fill", title: "Tips")
            InfoSheetHelpers.BulletPoint(text: "Identify and address neglected muscle groups")
            InfoSheetHelpers.BulletPoint(text: "Periodically add new exercises to your routine")
            InfoSheetHelpers.BulletPoint(text: "Regularly check your upper/lower body ratio")
        }
    }
}
