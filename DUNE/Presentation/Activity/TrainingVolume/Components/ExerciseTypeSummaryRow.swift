import SwiftUI

/// Row showing a single exercise type's aggregated stats.
/// Used in the exercise type list within TrainingVolumeDetailView.
struct ExerciseTypeSummaryRow: View {
    let exerciseType: ExerciseTypeVolume

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon
            typeIcon
                .foregroundStyle(exerciseType.color)
                .frame(width: 28, height: 28)
                .background(exerciseType.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

            // Name + sessions
            VStack(alignment: .leading, spacing: 2) {
                Text(exerciseType.displayName)
                    .font(.subheadline.weight(.medium))
                Text("\(exerciseType.sessionCount.formattedWithSeparator) sessions")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()

            // Duration + calories
            VStack(alignment: .trailing, spacing: 2) {
                Text(exerciseType.totalDuration.formattedDuration())
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(theme.heroTextGradient)
                if exerciseType.totalCalories > 0 {
                    Text("\(exerciseType.totalCalories.formattedWithSeparator()) kcal")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    @ViewBuilder
    private var typeIcon: some View {
        if let equipment = exerciseType.equipment {
            equipment.svgIcon(size: 18)
        } else {
            Image(systemName: exerciseType.iconName)
                .font(.system(size: 16))
        }
    }
}
