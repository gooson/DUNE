import SwiftUI

/// Sheet for reordering exercises during an active template workout.
/// Completed exercises are pinned and cannot be moved.
struct ExerciseReorderSheet: View {
    @Bindable var viewModel: TemplateWorkoutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.exercises, id: \.id) { exercise in
                    if let index = viewModel.exercises.firstIndex(where: { $0.id == exercise.id }) {
                        let status = viewModel.exerciseStatuses[index]
                        exerciseRow(exercise: exercise, status: status)
                            .moveDisabled(status == .completed)
                    }
                }
                .onMove { source, destination in
                    viewModel.moveExercise(from: source, to: destination)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func exerciseRow(exercise: ExerciseDefinition, status: TemplateExerciseStatus) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            statusIcon(for: status)
                .foregroundStyle(statusColor(for: status))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(exercise.localizedName)
                    .font(.body.weight(status == .inProgress ? .semibold : .regular))

                if !exercise.primaryMuscles.isEmpty {
                    Text(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Spacer()

            if status == .completed {
                Text("Done")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.Color.activity)
            }
        }
        .opacity(status == .completed ? 0.6 : 1.0)
    }

    @ViewBuilder
    private func statusIcon(for status: TemplateExerciseStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
        case .inProgress:
            Image(systemName: "circle.fill")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .skipped:
            Image(systemName: "forward.circle")
        }
    }

    private func statusColor(for status: TemplateExerciseStatus) -> Color {
        (status == .completed || status == .inProgress) ? DS.Color.activity : DS.Color.textSecondary
    }
}
