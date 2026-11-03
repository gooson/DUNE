import SwiftUI

/// Explains how exercise mix (frequency distribution) is analyzed.
struct ExerciseMixInfoSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

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
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background { SheetWaveBackground().opacity(0.55) }
        .accessibilityIdentifier("activity-exercise-mix-info-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.heroAccent)
                .padding(DS.Spacing.sm)
                .background(palette.heroAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            Text("Exercise Mix")
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.fill", title: "Overview")
            Text("Analyzes which exercises you perform and how often. Check the balance of your exercise mix and discover underworked areas.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .modifier(InfoSectionCard())
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.bar.fill", title: "How It's Measured")
            InfoSheetHelpers.BulletPoint(text: "Counts how often each exercise appears in the last 4 weeks")
            InfoSheetHelpers.BulletPoint(text: "Shows relative frequency as a percentage (%)")
            InfoSheetHelpers.BulletPoint(text: "Sorted by most frequently performed exercises")
        }
        .modifier(InfoSectionCard())
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "arrow.left.arrow.right", title: "Balanced Composition")
            InfoSheetHelpers.BulletPoint(text: "A push/pull/legs/core balance is recommended")
            InfoSheetHelpers.BulletPoint(text: "Over-reliance on certain exercises increases muscle imbalance and injury risk")
            InfoSheetHelpers.BulletPoint(text: "Aim for balanced full-body development with varied exercise patterns")
        }
        .modifier(InfoSectionCard())
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.max.fill", title: "Tips")
            InfoSheetHelpers.BulletPoint(text: "Identify and address neglected muscle groups")
            InfoSheetHelpers.BulletPoint(text: "Periodically add new exercises to your routine")
            InfoSheetHelpers.BulletPoint(text: "Regularly check your upper/lower body ratio")
        }
        .modifier(InfoSectionCard())
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

    private struct InfoSectionCard: ViewModifier {
        func body(content: Content) -> some View {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.md)
                .background(DS.Color.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
    }

}
