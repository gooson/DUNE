import SwiftUI

/// Explains how personal records are tracked and calculated.
struct PersonalRecordsInfoSheet: View {
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Personal Records (PR)")
                    .font(.headline)
                Text("Personal Records")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "lightbulb.fill", title: "Overview")
            Text("Tracks your personal bests by analyzing both strength and cardio records. View your progress on one screen and use it to adjust your training direction.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "scalemass.fill", title: "How It's Measured")
            InfoSheetHelpers.BulletPoint(text: "Strength PR: Based on average weight per set in a session")
            InfoSheetHelpers.BulletPoint(text: "Cardio PR: Based on pace/distance/time/calories/elevation")
            InfoSheetHelpers.BulletPoint(text: "Cardio prioritizes HealthKit data, supplemented by manual records when needed")
            InfoSheetHelpers.BulletPoint(text: "Abnormal values are automatically excluded (e.g., 0 or out-of-range values)")
        }
    }

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "apple.logo", title: "HealthKit Integration")
            InfoSheetHelpers.BulletPoint(text: "Displays heart rate, steps, weather, and indoor/outdoor info when available")
            InfoSheetHelpers.BulletPoint(text: "Cards are hidden with a notice when permissions are missing or data is unavailable")
        }
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "sparkles", title: "NEW Badge")
            InfoSheetHelpers.BulletPoint(text: "Shown on records updated within the last 7 days")
            InfoSheetHelpers.BulletPoint(text: "Visually track your consistent progress")
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "lightbulb.max.fill", title: "Tips")
            InfoSheetHelpers.BulletPoint(text: "Review weight trends for strength and pace/distance trends for cardio")
            InfoSheetHelpers.BulletPoint(text: "Use the NEW badge to quickly spot recent achievements")
            InfoSheetHelpers.BulletPoint(text: "Consistent repetition beats aggressive intensity for long-term gains")
        }
    }
}
