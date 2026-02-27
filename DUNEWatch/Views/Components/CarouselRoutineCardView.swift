import SwiftUI

/// Fullscreen routine card for the carousel home.
/// Displays exercise icon strip + routine name + meta info (exercises · sets · ~time).
struct CarouselRoutineCardView: View {
    let name: String
    let entries: [TemplateEntry]

    /// Maximum exercise icons to preview
    private let maxIconPreview = 4
    private let metaLabel: String

    init(name: String, entries: [TemplateEntry]) {
        self.name = name
        self.entries = entries

        // Pre-compute meta at init (Correction #102)
        let totalSets = entries.reduce(0) { $0 + $1.defaultSets }
        let estimatedMin = Self.estimateMinutes(entries: entries)
        var meta = "\(entries.count) exercise\(entries.count == 1 ? "" : "s") · \(totalSets) sets"
        if let mins = estimatedMin {
            meta += " · ~\(mins)min"
        }
        self.metaLabel = meta
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Section badge
            Text("ROUTINE")
                .font(DS.Typography.tinyLabel)
                .foregroundStyle(DS.Color.warmGlow)
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

    // MARK: - Estimation

    private static func estimateMinutes(entries: [TemplateEntry]) -> Int? {
        guard !entries.isEmpty else { return nil }
        let setExecutionSeconds: Double = 40
        var totalSeconds: Double = 0
        for entry in entries {
            let sets = Double(entry.defaultSets)
            let rest = entry.restDuration ?? 60
            totalSeconds += sets * setExecutionSeconds + Swift.max(sets - 1, 0) * rest
        }
        let minutes = Int((totalSeconds / 60).rounded())
        return minutes > 0 ? minutes : nil
    }
}
