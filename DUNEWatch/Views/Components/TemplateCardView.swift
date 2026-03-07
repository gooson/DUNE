import SwiftUI

/// Reusable template/routine card for the Watch home screen.
/// Shows template name, exercise icons, meta info (total sets, estimated time),
/// and a brief exercise name preview.
struct TemplateCardView: View {
    let name: String
    let entries: [TemplateEntry]

    /// Maximum number of exercise icons to preview
    private let maxIconPreview = 4

    @Environment(WatchConnectivityManager.self) private var connectivity

    private var metaLabel: String {
        routineMetaLabel(
            entries: entries,
            exerciseLibraryByID: connectivity.exerciseLibraryByID,
            globalRestSeconds: connectivity.globalRestSeconds
        )
    }

    private var exercisePreview: String {
        let names = entries.prefix(3).map(\.exerciseName)
        let preview = names.joined(separator: ", ")
        if entries.count > 3 {
            return preview + " +\(entries.count - 3)"
        }
        return preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Template name
            Text(name)
                .font(DS.Typography.tileTitle)
                .lineLimit(1)

            // Exercise icon strip
            exerciseIconStrip

            // Exercise name preview
            if !exercisePreview.isEmpty {
                Text(exercisePreview)
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Meta info (exercise count · total sets · estimated time)
            Text(metaLabel)
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: - Icon Strip

    private var exerciseIconStrip: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(entries.prefix(maxIconPreview).enumerated()), id: \.element.id) { _, entry in
                EquipmentIconView(equipment: entry.equipment, size: 18)
                    .frame(width: 18, height: 18)
            }

            if entries.count > maxIconPreview {
                Text("+\(entries.count - maxIconPreview)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
