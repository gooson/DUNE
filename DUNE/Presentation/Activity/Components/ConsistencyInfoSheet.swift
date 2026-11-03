import SwiftUI

/// Explains how workout consistency (streak) is calculated.
struct ConsistencyInfoSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                sectionCard { currentStreakSection }
                sectionCard { bestStreakSection }
                sectionCard { monthlySection }
                sectionCard { tipsSection }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background { SheetWaveBackground().opacity(0.55) }
        .accessibilityIdentifier("activity-consistency-info-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label("Workout Consistency", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(palette.ink)
            Label("Overview", systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
            Text("Tracks how consistently you work out. Check your consistency through workout streaks and monthly progress.")
                .font(.caption)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
                .allowsHitTesting(false)
        }
    }

    private func sectionHeader(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.activity)
                .padding(DS.Spacing.sm)
                .background(DS.Color.activity.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        StandardCard {
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var currentStreakSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "flame", title: "Current Streak")
            InfoSheetHelpers.BulletPoint(text: "Consecutive workout days including today or yesterday")
            InfoSheetHelpers.BulletPoint(text: "A day counts when at least one workout lasts 20 minutes or more.")
            InfoSheetHelpers.BulletPoint(text: "Missing a single day resets the streak")
        }
    }

    private var bestStreakSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "star.fill", title: "Best Streak")
            InfoSheetHelpers.BulletPoint(text: "Your longest consecutive workout record ever")
            InfoSheetHelpers.BulletPoint(text: "Automatically updated when the current streak exceeds the record")
        }
    }

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "calendar", title: "Monthly Progress")
            InfoSheetHelpers.BulletPoint(text: "Compare this month's qualifying workout days against your goal")
            InfoSheetHelpers.BulletPoint(text: "Default goal: 16 workout days per month (about 4 per week)")
            InfoSheetHelpers.BulletPoint(text: "Progress bar visualizes your completion rate")
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.max.fill", title: "Tips")
            InfoSheetHelpers.BulletPoint(text: "Consistency matters more than intensity for long-term results")
            InfoSheetHelpers.BulletPoint(text: "Aim to maintain a steady 3–5 sessions per week")
            InfoSheetHelpers.BulletPoint(text: "Rest days are essential for recovery — you don't need to train every day")
        }
    }
}
