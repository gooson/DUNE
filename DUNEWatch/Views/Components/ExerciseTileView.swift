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
            equipmentIcon
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

    // MARK: - Equipment Icon

    @ViewBuilder
    private var equipmentIcon: some View {
        if let equipment = exercise.equipment,
           let assetName = EquipmentIcon.assetName(for: equipment) {
            Image(assetName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(DS.Color.sandMuted)
        } else {
            Image(systemName: EquipmentIcon.sfSymbol(for: exercise.equipment))
                .font(.system(size: iconSize * 0.65))
                .foregroundStyle(DS.Color.sandMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
