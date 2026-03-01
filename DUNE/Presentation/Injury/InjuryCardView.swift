import SwiftUI

/// Card displaying an active or historical injury.
struct InjuryCardView: View {
    let record: InjuryRecord
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Severity indicator
                Circle()
                    .fill(record.severity.color.opacity(0.2))
                    .overlay {
                        Image(systemName: record.severity.iconName)
                            .font(.caption)
                            .foregroundStyle(record.severity.color)
                    }
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(record.bodyPart.displayName)
                            .font(.subheadline.weight(.semibold))
                        if let side = record.bodySide {
                            Text("(\(side.abbreviation))")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }

                    HStack(spacing: DS.Spacing.xs) {
                        Text(record.severity.displayName)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(record.severity.color.opacity(0.12), in: Capsule())
                            .foregroundStyle(record.severity.color)

                        Text(record.durationLabel)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Text(record.dateRangeLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if !record.memo.isEmpty {
                        Text(record.memo)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if record.isActive {
                    Circle()
                        .fill(record.severity.color)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}
