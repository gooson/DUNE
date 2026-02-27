import SwiftUI

/// Reusable template/routine card for the Watch home screen.
/// Shows template name, exercise count, and a preview of exercise icons.
struct TemplateCardView: View {
    let name: String
    let entries: [TemplateEntry]

    /// Maximum number of exercise icons to preview
    private let maxIconPreview = 4

    /// Pre-computed label (entries is immutable let — no per-render recomputation)
    private let exerciseCountLabel: String

    init(name: String, entries: [TemplateEntry]) {
        self.name = name
        self.entries = entries
        self.exerciseCountLabel = "\(entries.count) exercise\(entries.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Template name
            Text(name)
                .font(DS.Typography.tileTitle)
                .lineLimit(1)

            // Exercise icon strip + count
            HStack(spacing: DS.Spacing.sm) {
                exerciseIconStrip

                Spacer(minLength: 0)

                Text(exerciseCountLabel)
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }
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
