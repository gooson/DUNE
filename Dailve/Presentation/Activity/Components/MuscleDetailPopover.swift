import SwiftUI

/// Popover/sheet showing detailed recovery info for a single muscle group.
struct MuscleDetailPopover: View {
    let muscle: MuscleGroup
    let fatigueState: MuscleFatigueState?
    let library: ExerciseLibraryQuerying

    private var topExercises: [ExerciseDefinition] {
        Array(
            library.exercises(forMuscle: muscle)
                .filter { $0.category == .strength || $0.category == .bodyweight }
                .prefix(3)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
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
        .padding(DS.Spacing.xl)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func exerciseRow(_ exercise: ExerciseDefinition) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "dumbbell.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(exercise.localizedName)
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - Recovery Badge

    private var recoveryBadge: some View {
        let pct = fatigueState?.recoveryPercent ?? 1.0
        let color: Color
        let label: String

        if fatigueState?.lastTrainedDate == nil {
            color = .gray
            label = "No data"
        } else if pct >= 0.8 {
            color = .green
            label = "Ready"
        } else if pct >= 0.5 {
            color = .yellow
            label = "Recovering"
        } else {
            color = .red
            label = "Fatigued"
        }

        return Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(color.opacity(0.15), in: Capsule())
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
                title: "Recovery",
                value: state.recoveryPercent.isFinite ? "\(Int(state.recoveryPercent * 100))%" : "—",
                icon: "heart.fill"
            )
            statItem(
                title: "Weekly Volume",
                value: "\(state.weeklyVolume) sets",
                icon: "chart.bar.fill"
            )
            statItem(
                title: "Last Trained",
                value: lastTrainedText(state: state),
                icon: "clock.fill"
            )
            statItem(
                title: "Recovery Time",
                value: "\(Int(muscle.recoveryHours))h",
                icon: "timer"
            )
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
        if hours < 24 { return "\(Int(hours))h ago" }
        let days = Int(hours / 24)
        return "\(days)d ago"
    }
}
