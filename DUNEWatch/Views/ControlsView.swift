import SwiftUI

/// Workout controls page: End, Pause/Resume, and optionally Skip.
/// Used by both strength (vertical paging) and cardio (horizontal paging).
struct ControlsView: View {
    var showSkip: Bool = true

    @Environment(WorkoutManager.self) private var workoutManager

    @State private var showEndConfirmation = false
    @State private var showReorderSheet = false

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
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsEndButton)

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
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsPauseResumeButton)

            // Skip Exercise (strength only)
            if showSkip, !workoutManager.isCardioMode, !workoutManager.isLastExercise {
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
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsSkipButton)
            }

            // Reorder Exercises (strength only, 2+ non-completed)
            if showSkip, !workoutManager.isCardioMode, workoutManager.canReorderExercises {
                Button {
                    showReorderSheet = true
                } label: {
                    VStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.title3)
                        Text(String(localized: "Reorder"))
                            .font(DS.Typography.metricLabel)
                    }
                    .frame(maxWidth: .infinity)
                }
                .tint(.secondary)
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            WatchExerciseReorderView()
        }
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsScreen)
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
