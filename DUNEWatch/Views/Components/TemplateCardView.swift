import SwiftUI

/// Reusable template/routine card for the Watch home screen.
/// Shows template name, exercise icons, meta info (total sets, estimated time),
/// and a brief exercise name preview.
struct TemplateCardView: View {
    let name: String
    let entries: [TemplateEntry]

    /// Maximum number of exercise icons to preview
    private let maxIconPreview = 4

    /// Pre-computed labels (entries is immutable let — no per-render recomputation)
    private let metaLabel: String
    private let exercisePreview: String

    init(name: String, entries: [TemplateEntry]) {
        self.name = name
        self.entries = entries

        // Meta: "4 exercises · 16 sets · ~45min"
        let totalSets = entries.reduce(0) { $0 + $1.defaultSets }
        let estimatedMin = Self.estimateMinutes(entries: entries)
        var meta = "\(entries.count) exercise\(entries.count == 1 ? "" : "s") · \(totalSets) sets"
        if let mins = estimatedMin {
            meta += " · ~\(mins)min"
        }
        self.metaLabel = meta

        // Exercise name preview: first 3 names, truncated
        let names = entries.prefix(3).map(\.exerciseName)
        let preview = names.joined(separator: ", ")
        if entries.count > 3 {
            self.exercisePreview = preview + " +\(entries.count - 3)"
        } else {
            self.exercisePreview = preview
        }
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

    // MARK: - Estimation

    /// Estimates workout duration in minutes based on set count and rest durations.
    /// Returns nil if no entries exist.
    private static func estimateMinutes(entries: [TemplateEntry]) -> Int? {
        guard !entries.isEmpty else { return nil }
        // ~40s per set execution + rest between sets
        let setExecutionSeconds: Double = 40
        var totalSeconds: Double = 0
        for entry in entries {
            let sets = Double(entry.defaultSets)
            let rest = entry.restDuration ?? 60
            // Each set takes ~40s + rest between sets (no rest after last set)
            totalSeconds += sets * setExecutionSeconds + Swift.max(sets - 1, 0) * rest
        }
        let minutes = Int((totalSeconds / 60).rounded())
        return minutes > 0 ? minutes : nil
    }
}
