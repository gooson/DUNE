import SwiftUI

/// Explains how workout consistency (streak) is calculated.
struct ConsistencyInfoSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                currentStreakSection
                bestStreakSection
                monthlySection
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
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Workout Consistency")
                    .font(.headline)
                Text("Workout Consistency")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "lightbulb.fill", title: "Overview")
            Text("Tracks how consistently you work out. Check your consistency through workout streaks and monthly progress.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private var currentStreakSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "flame", title: "Current Streak")
            InfoSheetHelpers.BulletPoint(text: "Consecutive workout days including today or yesterday")
            InfoSheetHelpers.BulletPoint(text: "Only days with 20+ minutes of exercise count")
            InfoSheetHelpers.BulletPoint(text: "Missing a single day resets the streak")
        }
    }

    private var bestStreakSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "star.fill", title: "Best Streak")
            InfoSheetHelpers.BulletPoint(text: "Your longest consecutive workout record ever")
            InfoSheetHelpers.BulletPoint(text: "Automatically updated when the current streak exceeds the record")
        }
    }

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "calendar", title: "Monthly Progress")
            InfoSheetHelpers.BulletPoint(text: "Compare this month's workout count against your goal")
            InfoSheetHelpers.BulletPoint(text: "Default goal: 16 sessions per month (4x per week)")
            InfoSheetHelpers.BulletPoint(text: "Progress bar visualizes your completion rate")
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "lightbulb.max.fill", title: "Tips")
            InfoSheetHelpers.BulletPoint(text: "Consistency matters more than intensity for long-term results")
            InfoSheetHelpers.BulletPoint(text: "Aim to maintain a steady 3–5 sessions per week")
            InfoSheetHelpers.BulletPoint(text: "Rest days are essential for recovery — you don't need to train every day")
        }
    }
}
