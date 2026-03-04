import SwiftUI

/// Cardio workout controls accessible via right swipe (left page of horizontal paging).
/// Contains End and Pause/Resume buttons with confirmation dialog.
struct CardioControlsView: View {
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
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout") {
                workoutManager.end()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save and finish this workout?")
        }
    }
}
