import SwiftUI

/// Fullscreen routine card for the carousel home.
/// Displays exercise icon strip + routine name + meta info (exercises · sets · ~time).
struct CarouselRoutineCardView: View {
    let name: String
    let entries: [TemplateEntry]

    /// Maximum exercise icons to preview
    private let maxIconPreview = 4

    @Environment(\.appTheme) private var theme
    @Environment(WatchConnectivityManager.self) private var connectivity

    private var metaLabel: String {
        routineMetaLabel(
            entries: entries,
            exerciseLibraryByID: connectivity.exerciseLibraryByID,
            globalRestSeconds: connectivity.globalRestSeconds
        )
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Section badge
            Text("ROUTINE")
                .font(DS.Typography.tinyLabel)
                .foregroundStyle(theme.accentColor)
                .tracking(0.5)

            Spacer()

            // Exercise icon strip (centered, larger than list version)
            exerciseIconStrip

            // Routine name
            Text(name)
                .font(.system(.title3, design: .rounded).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)

            // Meta info
            Text(metaLabel)
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Icon Strip

    private var exerciseIconStrip: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(Array(entries.prefix(maxIconPreview).enumerated()), id: \.element.id) { _, entry in
                EquipmentIconView(equipment: entry.equipment, size: 32)
                    .frame(width: 32, height: 32)
            }

            if entries.count > maxIconPreview {
                Text("+\(entries.count - maxIconPreview)")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
