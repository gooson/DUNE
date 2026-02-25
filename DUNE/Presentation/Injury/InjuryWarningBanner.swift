import SwiftUI

/// Warning banner shown in Train tab when active injuries conflict with exercise muscles.
struct InjuryWarningBanner: View {
    let conflicts: [InjuryConflict]

    var body: some View {
        if !conflicts.isEmpty {
            let maxSeverity = conflicts.map(\.severity).max() ?? .moderate

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: maxSeverity == .severe ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(maxSeverity.color)

                    Text(headerText(maxSeverity: maxSeverity))
                        .font(.subheadline.weight(.semibold))
                }

                ForEach(conflicts) { conflict in
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(conflict.severity.color)
                            .frame(width: 6, height: 6)

                        Text(conflict.injury.bodyPart.bilingualDisplayName)
                            .font(.caption.weight(.medium))

                        if !conflict.conflictingMuscles.isEmpty {
                            Text("(\(conflict.conflictingMuscles.map(\.displayName).joined(separator: ", ")))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(maxSeverity.color.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(maxSeverity.color.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func headerText(maxSeverity: InjurySeverity) -> String {
        switch maxSeverity {
        case .severe:
            return "Injury Warning — Avoid These Muscles"
        case .moderate:
            return "Caution — Injured Area Involved"
        case .minor:
            return "Note — Minor Injury in This Area"
        }
    }
}
