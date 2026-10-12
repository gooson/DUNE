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
            WorkoutExerciseIcon(
                exerciseID: exercise.id,
                name: exercise.name,
                inputType: exercise.inputType,
                equipment: exercise.equipment,
                size: iconSize
            )
            .padding(DS.Spacing.xs)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(exercise.name)
                    .font(DS.Typography.tileTitle)
                    .lineLimit(2)

                Text(subtitle)
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Uses the activity symbol for cardio and the existing asset mapping for equipment.
/// Resolution happens at initialization, outside scrolling view rendering.
struct WorkoutExerciseIcon: View {
    private let activitySymbol: String?
    private let equipment: String?
    private let size: CGFloat
    @Environment(\.appTheme) private var theme

    init(exerciseID: String, name: String, inputType: String?, equipment: String?, size: CGFloat) {
        self.activitySymbol = WorkoutActivityType.resolveCardioActivity(
            from: exerciseID,
            name: name,
            inputTypeRaw: inputType
        )?.iconName
        self.equipment = equipment
        self.size = size
    }

    var body: some View {
        Group {
            if let activitySymbol {
                Image(systemName: activitySymbol)
                    .font(.system(size: size * 0.8, weight: .medium))
                    .foregroundStyle(theme.sandColor)
            } else {
                EquipmentIconView(equipment: equipment, size: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
