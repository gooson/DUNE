import SwiftUI

/// Workout controls page: End, Pause/Resume, and optionally Skip.
/// Used by both strength (vertical paging) and cardio (horizontal paging).
struct ControlsView: View {
    var showSkip: Bool = true

    @Environment(WorkoutManager.self) private var workoutManager

    @State private var showEndConfirmation = false
    @State private var showReorderSheet = false

    var body: some View {
        GeometryReader { geometry in
            let spacing = min(DS.Spacing.lg, max(DS.Spacing.xs, geometry.size.height * 0.035))

            ViewThatFits(in: .vertical) {
                controlsGrid(spacing: spacing)

                ScrollView {
                    controlsGrid(spacing: spacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showReorderSheet) {
            WatchExerciseReorderView()
        }
        .accessibilityElement(children: .contain)
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

    private func controlsGrid(spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                Button(role: .destructive) {
                    showEndConfirmation = true
                } label: {
                    controlLabel("End", systemImage: "xmark")
                }
                .tint(DS.Color.negative)
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsEndButton)

                Button {
                    if workoutManager.isPaused {
                        workoutManager.resume()
                    } else {
                        workoutManager.pause()
                    }
                } label: {
                    controlLabel(
                        workoutManager.isPaused ? "Resume" : "Pause",
                        systemImage: workoutManager.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .tint(DS.Color.caution)
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsPauseResumeButton)
            }

            if showSkip, !workoutManager.isCardioMode,
               !workoutManager.isLastExercise || workoutManager.canReorderExercises {
                HStack(spacing: spacing) {
                    if !workoutManager.isLastExercise {
                        Button {
                            workoutManager.skipExercise()
                        } label: {
                            controlLabel("Skip", systemImage: "forward.fill")
                        }
                        .tint(.secondary)
                        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsSkipButton)
                    }

                    if workoutManager.canReorderExercises {
                        Button {
                            showReorderSheet = true
                        } label: {
                            controlLabel("Reorder", systemImage: "arrow.up.arrow.down")
                        }
                        .tint(.secondary)
                        .accessibilityIdentifier("watch-session-controls-reorder-button")
                    }
                }
            }
        }
    }

    private func controlLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: systemImage)
                .font(.title3)
            Text(title)
                .font(DS.Typography.metricLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
    }
}
