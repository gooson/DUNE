import SwiftUI

/// Sheet for reordering exercises during an active template workout.
/// Completed exercises are pinned and cannot be moved.
struct ExerciseReorderSheet: View {
    @Bindable var viewModel: TemplateWorkoutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.exercises.indices, id: \.self) { index in
                    exerciseRow(index: index)
                        .moveDisabled(viewModel.exerciseStatuses[index] == .completed)
                }
                .onMove { source, destination in
                    withAnimation {
                        viewModel.moveExercise(from: source, to: destination)
                    }
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

    private func exerciseRow(index: Int) -> some View {
        let exercise = viewModel.exercises[index]
        let status = viewModel.exerciseStatuses[index]

        return HStack(spacing: DS.Spacing.sm) {
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
        switch status {
        case .completed: DS.Color.activity
        case .inProgress: DS.Color.activity
        case .skipped: DS.Color.textSecondary
        case .pending: DS.Color.textSecondary
        }
    }
}
