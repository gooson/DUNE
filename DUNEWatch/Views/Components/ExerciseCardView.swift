import SwiftUI

/// Fullscreen exercise card with a compact identity panel and a clear preview action.
/// Display data is pre-computed by the caller; rendering does not read UserDefaults.
struct ExerciseCardView: View {
    let exercise: WatchExerciseInfo
    let sectionLabel: String
    let sectionColor: Color
    let daysAgo: String?

    private let subtitle: String

    init(exercise: WatchExerciseInfo, sectionLabel: String, sectionColor: Color, daysAgo: String?) {
        self.exercise = exercise
        self.sectionLabel = sectionLabel
        self.sectionColor = sectionColor
        self.daysAgo = daysAgo
        self.subtitle = exerciseSubtitle(for: exercise)
    }

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(sectionLabel)
                .font(DS.Typography.metricLabel)
                .foregroundStyle(sectionColor)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.md) {
                    WorkoutExerciseIcon(
                        exerciseID: exercise.id,
                        name: exercise.name,
                        inputType: exercise.inputType,
                        equipment: exercise.equipment,
                        size: 32
                    )
                    .padding(DS.Spacing.xs)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                    Text(exercise.name)
                        .font(DS.Typography.exerciseName)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(subtitle)
                    .font(DS.Typography.tileSubtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let daysAgo {
                    Text(daysAgo)
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))

            Label("Start", systemImage: "play.fill")
                .font(DS.Typography.tileSubtitle)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(theme.accentColor)
                .background(theme.accentColor.opacity(DS.Opacity.border), in: Capsule())
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
