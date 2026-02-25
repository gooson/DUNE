import SwiftUI

/// Left page of SessionPagingView: End, Pause/Resume, Skip controls.
struct ControlsView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    @State private var showEndConfirmation = false

    var body: some View {
        VStack(spacing: 12) {
            // End Workout
            Button(role: .destructive) {
                showEndConfirmation = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "xmark")
                        .font(.title3)
                    Text("End")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
            }
            .tint(.red)

            // Pause / Resume
            Button {
                if workoutManager.isPaused {
                    workoutManager.resume()
                } else {
                    workoutManager.pause()
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                    Text(workoutManager.isPaused ? "Resume" : "Pause")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
            }
            .tint(.yellow)

            // Skip Exercise
            if !workoutManager.isLastExercise {
                Button {
                    workoutManager.skipExercise()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                        Text("Skip")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .tint(.gray)
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
            if workoutManager.completedSetsData.flatMap({ $0 }).isEmpty {
                Text("No sets recorded. End without saving?")
            } else {
                Text("Save and finish this workout?")
            }
        }
    }
}
