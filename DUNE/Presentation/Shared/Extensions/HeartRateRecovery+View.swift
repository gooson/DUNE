import SwiftUI

extension HeartRateRecovery.Rating {
    var color: Color {
        switch self {
        case .low: .red
        case .normal: .yellow
        case .good: .green
        }
    }
}

/// Shared recovery row displayed in workout detail views.
struct HeartRateRecoveryRow: View {
    let recovery: HeartRateRecovery

    @State private var showingInfoSheet = false

    var body: some View {
        if recovery.hrr1 > 0 {
            let ratingColor = recovery.rating.color
            HStack {
                Label("Recovery", systemImage: "arrow.down.heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)

                Button {
                    showingInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("heart-rate-recovery-info-button")

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Text("\(Int(recovery.hrr1))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("bpm")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text(recovery.rating.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ratingColor)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            ratingColor.opacity(0.15),
                            in: Capsule()
                        )
                }
            }
            .padding(.top, DS.Spacing.xs)
            .sheet(isPresented: $showingInfoSheet) {
                HeartRateRecoveryInfoSheet()
            }
        }
    }
}

// MARK: - Info Sheet

/// Explains what HRR₁ means and how the rating is determined.
struct HeartRateRecoveryInfoSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                explanationCard(icon: "heart.text.clipboard", title: "Definition", identifier: "heart-rate-recovery-info-definition") {
                    Text("Heart Rate Recovery (HRR₁) measures how quickly your heart rate drops in the first minute after exercise. A faster drop indicates better cardiovascular fitness and autonomic nervous system recovery.")
                }
                explanationCard(icon: "applewatch", title: "How It's Measured", identifier: "heart-rate-recovery-info-measurement") {
                    Text("Your peak heart rate at the end of the workout is compared to the heart rate measured about 60 seconds after the workout ends. The difference is your HRR₁ value.")
                }
                ratingGuideSection
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("heart-rate-recovery-info-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top) {
                    headerIcon
                    Spacer(minLength: DS.Spacing.sm)
                    headerCloseButton
                }
                headerTitle
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    headerIcon
                    headerTitle
                    headerCloseButton
                }
            }

            Image(systemName: "arrow.down.heart.fill")
                .font(.system(size: 42))
                .foregroundStyle(palette.heroAccent)
                .frame(width: 74, height: 74)
                .background(palette.heroAccent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay { RoundedRectangle(cornerRadius: DS.Radius.xl).strokeBorder(palette.border, lineWidth: 1) }
    }

    private var headerIcon: some View {
        Image(systemName: "info.circle.fill")
            .font(.title3.weight(.semibold))
            .foregroundStyle(palette.heroAccent)
            .padding(DS.Spacing.sm)
            .background(palette.heroAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .accessibilityHidden(true)
    }

    private var headerTitle: some View {
        Text("What is Heart Rate Recovery?")
            .font(.title3.bold())
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("heart-rate-recovery-info-title")
    }

    private var headerCloseButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.ink)
                .frame(width: 48, height: 48)
                .background(palette.ink.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close"))
        .accessibilityIdentifier("heart-rate-recovery-info-close")
    }

    private func explanationCard<Content: View>(
        icon: String,
        title: LocalizedStringKey,
        identifier: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                InfoSheetHelpers.SectionHeader(icon: icon, title: title)
                    .accessibilityElement(children: .combine)
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

    private var ratingGuideSection: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                InfoSheetHelpers.SectionHeader(icon: "gauge.with.needle", title: "Rating Guide")
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("heart-rate-recovery-info-guide")
                VStack(spacing: 0) {
                    ratingRow(label: "Good", range: "> 20 bpm", color: HeartRateRecovery.Rating.good.color, identifier: "heart-rate-recovery-info-rating-good")
                    Divider()
                    ratingRow(label: "Normal", range: "12–20 bpm", color: HeartRateRecovery.Rating.normal.color, identifier: "heart-rate-recovery-info-rating-normal")
                    Divider()
                    ratingRow(label: "Low", range: "< 12 bpm", color: HeartRateRecovery.Rating.low.color, identifier: "heart-rate-recovery-info-rating-low")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ratingRow(label: LocalizedStringKey, range: String, color: Color, identifier: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.md) {
                        ratingDot(color)
                        Text(label).font(.subheadline)
                    }
                    Text(range)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(.leading, 8 + DS.Spacing.md)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                    ratingDot(color)
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

    private func ratingDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

#Preview {
    HeartRateRecoveryInfoSheet()
}
