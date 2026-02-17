import SwiftUI

struct BodySnapshotCard: View {
    let latestItem: BodyCompositionListItem
    let previousItem: BodyCompositionListItem?

    /// Minimum absolute change to display (noise floor for scale precision)
    private static let changeDisplayThreshold = 0.05

    var body: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.lg) {
                    if let weight = latestItem.weight {
                        metricColumn(
                            label: "Weight",
                            value: String(format: "%.1f", weight),
                            unit: "kg",
                            change: previousItem?.weight.map { weight - $0 }
                        )
                    }
                    if let fat = latestItem.bodyFatPercentage {
                        metricColumn(
                            label: "Body Fat",
                            value: String(format: "%.1f", fat),
                            unit: "%",
                            change: previousItem?.bodyFatPercentage.map { fat - $0 }
                        )
                    }
                    if let muscle = latestItem.muscleMass {
                        metricColumn(
                            label: "Muscle",
                            value: String(format: "%.1f", muscle),
                            unit: "kg",
                            change: previousItem?.muscleMass.map { muscle - $0 }
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                // Source + date
                HStack(spacing: DS.Spacing.xs) {
                    if latestItem.source == .healthKit {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    Text(latestItem.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func metricColumn(label: String, value: String, unit: String, change: Double?) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let change {
                changeLabel(change)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func changeLabel(_ change: Double) -> some View {
        let absChange = abs(change)
        let text: String
        let color: Color

        if absChange < Self.changeDisplayThreshold {
            text = "—"
            color = .secondary
        } else if change > 0 {
            text = "+\(String(format: "%.1f", absChange))"
            color = .primary
        } else {
            text = "-\(String(format: "%.1f", absChange))"
            color = .primary
        }

        return Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
    }
}
