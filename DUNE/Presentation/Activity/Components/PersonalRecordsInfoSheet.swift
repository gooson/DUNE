import SwiftUI

/// Explains how personal records are tracked and calculated.
struct PersonalRecordsInfoSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                measurementSection
                healthKitSection
                badgeSection
                tipsSection
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background { SheetWaveBackground().opacity(0.55) }
        .accessibilityIdentifier("activity-personal-records-info-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(palette.heroAccent)
                .padding(DS.Spacing.sm)
                .background(palette.heroAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Personal Records (PR)")
                    .font(.title3.bold())
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay { RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(palette.border, lineWidth: 1) }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.fill", title: "Overview")
            Text("Tracks your personal bests by analyzing both strength and cardio records. View your progress on one screen and use it to adjust your training direction.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "scalemass.fill", title: "How It's Measured")
            InfoSheetHelpers.BulletPoint(text: "Strength records include weight records, estimated 1RM, rep-max records, and session volume.")
            InfoSheetHelpers.BulletPoint(text: "Cardio PR: Based on pace/distance/time/calories/elevation")
            InfoSheetHelpers.BulletPoint(text: "Cardio prioritizes HealthKit data, supplemented by manual records when needed")
            InfoSheetHelpers.BulletPoint(text: "Abnormal values are automatically excluded (e.g., 0 or out-of-range values)")
        }
    }

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "apple.logo", title: "HealthKit Integration")
            InfoSheetHelpers.BulletPoint(text: "Displays heart rate, steps, weather, and indoor/outdoor info when available")
            InfoSheetHelpers.BulletPoint(text: "Cards are hidden with a notice when permissions are missing or data is unavailable")
        }
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "sparkles", title: "NEW Badge")
            InfoSheetHelpers.BulletPoint(text: "Shown on records updated within the last 7 days")
            InfoSheetHelpers.BulletPoint(text: "Visually track your consistent progress")
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.max.fill", title: "Tips")
            InfoSheetHelpers.BulletPoint(text: "Review weight trends for strength and pace/distance trends for cardio")
            InfoSheetHelpers.BulletPoint(text: "Use the NEW badge to quickly spot recent achievements")
            InfoSheetHelpers.BulletPoint(text: "Consistent repetition beats aggressive intensity for long-term gains")
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

}
