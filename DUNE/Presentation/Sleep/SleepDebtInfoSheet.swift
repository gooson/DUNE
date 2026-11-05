import SwiftUI

/// Explains how sleep debt is calculated — shown from the gauge's info button.
struct SleepDebtInfoSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                explanationCard(icon: "chart.line.flattrend.xyaxis", title: "Baseline", identifier: "sleep-debt-info-baseline") {
                    Text("Your personal baseline is the average sleep duration over the last 14 days. Days with no sleep data are excluded.")
                }
                explanationCard(icon: "calendar", title: "How It Adds Up", identifier: "sleep-debt-info-calculation") {
                    Text("Each day in the last 7 days is compared against your 14-day average. If you slept less than average, the shortfall is added to your debt.")
                }
                explanationCard(icon: "moon.zzz", title: "Excess Sleep", identifier: "sleep-debt-info-excess") {
                    Text("Sleeping more than average on a given day does not reduce your accumulated debt. Each day's deficit is capped at zero — extra sleep won't cancel out previous shortfalls.")
                }
                levelTableSection
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background { SheetWaveBackground().opacity(0.55) }
        .accessibilityIdentifier("sleep-debt-info-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "info.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.heroAccent)
                    .padding(DS.Spacing.sm)
                    .background(palette.heroAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .accessibilityHidden(true)

                Text("How Sleep Debt Works")
                    .font(.title3.bold())
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("sleep-debt-info-title")

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 44, height: 44)
                        .background(palette.ink.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("sleep-debt-info-close")
            }

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "chart.line.flattrend.xyaxis")
                Rectangle().frame(height: 1)
                Image(systemName: "calendar")
                Rectangle().frame(height: 1)
                Image(systemName: "sum")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.heroAccent)
            .frame(maxWidth: 240)
            .accessibilityHidden(true)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay { RoundedRectangle(cornerRadius: DS.Radius.xl).strokeBorder(palette.border, lineWidth: 1) }
    }

    private func explanationCard<Content: View>(
        icon: String,
        title: LocalizedStringKey,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                sectionHeader(icon: icon, title: title)
                    .accessibilityIdentifier(identifier)
                content()
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier)-body")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var levelTableSection: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                sectionHeader(icon: "gauge.with.needle", title: "Levels")
                    .accessibilityIdentifier("sleep-debt-info-levels")
                VStack(spacing: 0) {
                    levelRow(label: Labels.wellRested, range: "< 2h", icon: "moon.stars.fill", color: DS.Color.scoreGood, identifier: "sleep-debt-info-level-well-rested")
                    Divider()
                    levelRow(label: Labels.slightlyShort, range: "2–5h", icon: "moon.fill", color: DS.Color.scoreFair, identifier: "sleep-debt-info-level-slightly-short")
                    Divider()
                    levelRow(label: Labels.sleepDebt, range: "5–10h", icon: "moon.zzz.fill", color: DS.Color.scoreTired, identifier: "sleep-debt-info-level-sleep-debt")
                    Divider()
                    levelRow(label: Labels.severeDebt, range: "> 10h", icon: "exclamationmark.circle.fill", color: DS.Color.scoreWarning, identifier: "sleep-debt-info-level-severe")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.sleep)
                .frame(width: 32, height: 32)
                .background(DS.Color.sleep.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func levelRow(label: String, range: String, icon: String, color: Color, identifier: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.md) {
                        levelIcon(icon, color: color)
                        Text(label).font(.subheadline)
                    }
                    Text(range)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(.leading, 32 + DS.Spacing.md)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                    levelIcon(icon, color: color)
                    Text(label)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(range)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func levelIcon(_ icon: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
        }
        .frame(width: 32)
        .accessibilityHidden(true)
    }

    private enum Labels {
        static let wellRested = String(localized: "Well Rested")
        static let slightlyShort = String(localized: "Slightly Short")
        static let sleepDebt = String(localized: "Sleep Debt")
        static let severeDebt = String(localized: "Severe Debt")
    }
}

#Preview {
    SleepDebtInfoSheet()
}
