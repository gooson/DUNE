import SwiftUI

/// Popover/sheet showing detailed recovery info for a single muscle group.
/// When `isInline` is true, renders as an inline section (e.g., inside MuscleMapDetailView)
/// instead of a sheet presentation.
struct MuscleDetailPopover: View {
    let muscle: MuscleGroup
    let fatigueState: MuscleFatigueState?
    let library: ExerciseLibraryQuerying
    var isInline: Bool = false

    @State private var showingInfoSheet = false
    @State private var topExercises: [ExerciseDefinition] = []

    var body: some View {
        content
            .task(id: muscle) {
                topExercises = Array(
                    library.exercises(forMuscle: muscle)
                        .filter { $0.category == .strength || $0.category == .bodyweight }
                        .prefix(3)
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        if isInline {
            inlineBody
                .padding(DS.Spacing.lg)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        } else {
            inlineBody
                .padding(DS.Spacing.xl)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var inlineBody: some View {
        VStack(alignment: .leading, spacing: isInline ? DS.Spacing.md : DS.Spacing.lg) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: muscle.iconName)
                    .font(.title3)
                    .foregroundStyle(DS.Color.activity)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(muscle.displayName)
                        .font(.headline)
                    Text(muscle.localizedDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                recoveryBadge
            }

            // Stats grid
            if let state = fatigueState {
                statsGrid(state: state)

                if let score = state.compoundScore {
                    Button {
                        showingInfoSheet = true
                    } label: {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("계산 방법 보기")
                                .font(.caption)
                        }
                        .foregroundStyle(DS.Color.activity)
                    }
                    .sheet(isPresented: $showingInfoSheet) {
                        FatigueInfoSheet(score: score)
                    }
                }
            } else if isInline {
                Text("No recent activity for this muscle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Recommended exercises
            if !topExercises.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Exercises")
                        .font(.subheadline.weight(.semibold))

                    ForEach(topExercises) { (exercise: ExerciseDefinition) in
                        exerciseRow(exercise)
                    }
                }
            }
        }
    }

    private func exerciseRow(_ exercise: ExerciseDefinition) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(exercise.equipment.svgAssetName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .frame(width: 20)
            Text(exercise.localizedName)
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - Recovery Badge

    @Environment(\.colorScheme) private var colorScheme

    private var recoveryBadge: some View {
        let level = fatigueState?.fatigueLevel ?? .noData
        let color = level.color(for: colorScheme)
        let badgeBackground = color.opacity(0.15)

        return HStack(spacing: DS.Spacing.xxs) {
            Text(level.shortLabel)
                .font(.caption2.weight(.bold).monospacedDigit())
            Text(level.displayName)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(badgeBackground, in: Capsule())
        .foregroundStyle(color)
    }

    // MARK: - Stats Grid

    private func statsGrid(state: MuscleFatigueState) -> some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]

        return LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
            statItem(
                title: "Fatigue Level",
                value: "\(state.fatigueLevel.shortLabel) / L10",
                icon: "flame.fill"
            )
            statItem(
                title: "Weekly Volume",
                value: "\(state.weeklyVolume.formattedWithSeparator) sets",
                icon: "chart.bar.fill"
            )
            statItem(
                title: "Last Trained",
                value: lastTrainedText(state: state),
                icon: "clock.fill"
            )
            if let score = state.compoundScore {
                statItem(
                    title: "Sleep Modifier",
                    value: "\(score.breakdown.sleepModifier.formattedWithSeparator(fractionDigits: 2))×",
                    icon: "moon.fill"
                )
            } else {
                statItem(
                    title: "Base Recovery",
                    value: "\(Int(muscle.recoveryHours).formattedWithSeparator)h",
                    icon: "timer"
                )
            }
        }
    }

    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.sm)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func lastTrainedText(state: MuscleFatigueState) -> String {
        guard let hours = state.hoursSinceLastTrained, hours.isFinite else { return "Never" }
        if hours < 1 { return "Just now" }
        if hours < 24 { return "\(Int(hours).formattedWithSeparator)h ago" }
        let days = Int(hours / 24)
        return "\(days.formattedWithSeparator)d ago"
    }
}
