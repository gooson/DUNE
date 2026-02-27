import SwiftUI

/// Reusable exercise tile for Watch quick-start lists.
/// Displays equipment icon (asset or SF Symbol fallback) alongside exercise name and defaults.
struct ExerciseTileView: View {
    let exercise: WatchExerciseInfo
    let subtitle: String

    /// Icon size adapts to tile context (list row vs standalone card)
    var iconSize: CGFloat = 28

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            EquipmentIconView(equipment: exercise.equipment, size: iconSize)
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(exercise.name)
                    .font(DS.Typography.tileTitle)
                    .lineLimit(1)

                Text(subtitle)
                    .font(DS.Typography.tileSubtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
