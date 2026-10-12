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
            let spacing = DS.Spacing.lg
            let primaryHeight = workoutManager.isCardioMode
                ? max(64, min(96, (geometry.size.height - spacing) / 2))
                : max(64, min(100, (geometry.size.height - spacing) * 0.58))
            let secondaryHeight = max(48, min(64, geometry.size.height - primaryHeight - spacing))

            ViewThatFits(in: .vertical) {
                controlsGrid(spacing: spacing, primaryHeight: primaryHeight, secondaryHeight: secondaryHeight)

                ScrollView {
                    controlsGrid(spacing: spacing, primaryHeight: primaryHeight, secondaryHeight: secondaryHeight)
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
                .accessibilityIdentifier("watch-session-end-cancel")
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

    private func controlsGrid(spacing: CGFloat, primaryHeight: CGFloat, secondaryHeight: CGFloat) -> some View {
        VStack(spacing: spacing) {
            if workoutManager.isCardioMode {
                pauseResumeButton(height: primaryHeight)
                endButton(height: primaryHeight)
            } else {
                HStack(spacing: spacing) {
                    pauseResumeButton(height: primaryHeight)
                    endButton(height: primaryHeight)
                }
            }

            if showSkip, !workoutManager.isCardioMode,
               !workoutManager.isLastExercise || workoutManager.canReorderExercises {
                HStack(spacing: spacing) {
                    if !workoutManager.isLastExercise {
                        Button {
                            workoutManager.skipExercise()
                        } label: {
                            controlLabel("Skip", systemImage: "forward.fill", tint: .secondary,
                                         height: secondaryHeight, isPrimary: false)
                        }
                        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsSkipButton)
                    }

                    if workoutManager.canReorderExercises {
                        Button {
                            showReorderSheet = true
                        } label: {
                            controlLabel("Reorder", systemImage: "arrow.up.arrow.down", tint: .secondary,
                                         height: secondaryHeight, isPrimary: false)
                        }
                        .accessibilityIdentifier("watch-session-controls-reorder-button")
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.xs)
    }

    private func pauseResumeButton(height: CGFloat) -> some View {
        Button {
            if workoutManager.isPaused {
                workoutManager.resume()
            } else {
                workoutManager.pause()
            }
        } label: {
            controlLabel(
                workoutManager.isPaused ? "Resume" : "Pause",
                systemImage: workoutManager.isPaused ? "play.fill" : "pause.fill",
                tint: DS.Color.caution,
                height: height,
                isPrimary: true
            )
        }
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsPauseResumeButton)
    }

    private func endButton(height: CGFloat) -> some View {
        Button(role: .destructive) {
            showEndConfirmation = true
        } label: {
            controlLabel("End", systemImage: "xmark", tint: DS.Color.negative,
                         height: height, isPrimary: true)
        }
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsEndButton)
    }

    private func controlLabel(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        height: CGFloat,
        isPrimary: Bool
    ) -> some View {
        VStack(spacing: isPrimary ? DS.Spacing.sm : DS.Spacing.xs) {
            Image(systemName: systemImage)
                .font(isPrimary ? .title2.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(isPrimary ? .callout.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: height)
        .background(tint.opacity(DS.Opacity.overlay), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
}
