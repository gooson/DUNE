import SwiftUI

/// Left page of SessionPagingView: End, Pause/Resume, Skip controls.
struct ControlsView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    @State private var showEndConfirmation = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // End Workout
            Button(role: .destructive) {
                showEndConfirmation = true
            } label: {
                VStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "xmark")
                        .font(.title3)
                    Text("End")
                        .font(DS.Typography.metricLabel)
                }
                .frame(maxWidth: .infinity)
            }
            .tint(DS.Color.negative)

            // Pause / Resume
            Button {
                if workoutManager.isPaused {
                    workoutManager.resume()
                } else {
                    workoutManager.pause()
                }
            } label: {
                VStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                    Text(workoutManager.isPaused ? "Resume" : "Pause")
                        .font(DS.Typography.metricLabel)
                }
                .frame(maxWidth: .infinity)
            }
            .tint(DS.Color.caution)

            // Skip Exercise (strength mode only — cardio has no exercise list)
            if !workoutManager.isCardioMode, !workoutManager.isLastExercise {
                Button {
                    workoutManager.skipExercise()
                } label: {
                    VStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                        Text("Skip")
                            .font(DS.Typography.metricLabel)
                    }
                    .frame(maxWidth: .infinity)
                }
                .tint(.secondary)
            }
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) {
                workoutManager.end()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if workoutManager.isCardioMode {
                Text("Save and finish this workout?")
            } else if workoutManager.completedSetsData.flatMap({ $0 }).isEmpty {
                Text("No sets recorded. End without saving?")
            } else {
                Text("Save and finish this workout?")
            }
        }
    }
}
