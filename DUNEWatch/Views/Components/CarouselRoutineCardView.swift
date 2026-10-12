import SwiftUI

/// Fullscreen routine card for the carousel home.
/// Displays exercise icon strip + routine name + meta info (exercises · sets · ~time).
struct CarouselRoutineCardView: View {
    let name: String
    let entries: [TemplateEntry]

    @Environment(\.appTheme) private var theme
    @Environment(WatchConnectivityManager.self) private var connectivity

    private var metaLabel: String {
        routineMetaLabel(
            entries: entries,
            exerciseLibraryByID: connectivity.exerciseLibraryByID,
            globalRestSeconds: connectivity.globalRestSeconds
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("ROUTINE")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(theme.accentColor)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.md) {
                    if let first = entries.first {
                        WorkoutExerciseIcon(
                            exerciseID: first.exerciseDefinitionID,
                            name: first.exerciseName,
                            inputType: connectivity.exerciseInfo(for: first.exerciseDefinitionID)?.inputType ?? first.inputTypeRaw,
                            equipment: first.equipment,
                            size: 32
                        )
                        .padding(DS.Spacing.xs)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    Text(name)
                        .font(DS.Typography.exerciseName)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(metaLabel)
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let first = entries.first {
                    Divider()
                    Text(first.exerciseName)
                        .font(DS.Typography.tileSubtitle)
                        .lineLimit(1)
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
