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
            let spacing = geometry.size.height < 180 ? DS.Spacing.sm : DS.Spacing.lg
            let hasSecondaryActions = showSkip && !workoutManager.isCardioMode
                && (!workoutManager.isLastExercise || workoutManager.canReorderExercises)
            let reservedHeight = 24 + spacing * 2 + DS.Spacing.xs
            let primaryHeight = workoutManager.isCardioMode
                ? max(44, min(96, (geometry.size.height - spacing - DS.Spacing.xs) / 2))
                : hasSecondaryActions
                    ? max(44, min(76, geometry.size.height - reservedHeight - 48))
                    : max(44, min(64, (geometry.size.height - reservedHeight) / 2))
            let secondaryHeight: CGFloat = 48

            ViewThatFits(in: .vertical) {
                controlsContent(spacing: spacing, primaryHeight: primaryHeight,
                                secondaryHeight: secondaryHeight, hasSecondaryActions: hasSecondaryActions)

                ScrollView {
                    controlsContent(spacing: spacing, primaryHeight: primaryHeight,
                                    secondaryHeight: secondaryHeight, hasSecondaryActions: hasSecondaryActions)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private func controlsContent(
        spacing: CGFloat,
        primaryHeight: CGFloat,
        secondaryHeight: CGFloat,
        hasSecondaryActions: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            if !workoutManager.isCardioMode {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Controls")
                        .font(.system(size: 16, weight: .semibold))
                    if hasSecondaryActions,
                       let snapshot = workoutManager.templateSnapshot,
                       snapshot.entries.indices.contains(workoutManager.currentExerciseIndex) {
                        Text(snapshot.entries[workoutManager.currentExerciseIndex].exerciseName)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(minHeight: 24)
                .padding(.horizontal, DS.Spacing.sm)
            }

            controlsGrid(spacing: spacing, primaryHeight: primaryHeight,
                         secondaryHeight: secondaryHeight, hasSecondaryActions: hasSecondaryActions)
        }
        .padding(.top, DS.Spacing.xs)
    }

    private func controlsGrid(
        spacing: CGFloat,
        primaryHeight: CGFloat,
        secondaryHeight: CGFloat,
        hasSecondaryActions: Bool
    ) -> some View {
        VStack(spacing: spacing) {
            if workoutManager.isCardioMode || !hasSecondaryActions {
                pauseResumeButton(height: primaryHeight, horizontal: !workoutManager.isCardioMode)
                endButton(height: primaryHeight, horizontal: !workoutManager.isCardioMode)
            } else {
                HStack(spacing: spacing) {
                    pauseResumeButton(height: primaryHeight)
                    endButton(height: primaryHeight)
                }
            }

            if hasSecondaryActions {
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

    private func pauseResumeButton(height: CGFloat, horizontal: Bool = false) -> some View {
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
                isPrimary: true,
                horizontal: horizontal
            )
        }
        .accessibilityLabel(workoutManager.isPaused ? Text("Resume") : Text("Pause"))
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsPauseResumeButton)
    }

    private func endButton(height: CGFloat, horizontal: Bool = false) -> some View {
        Button(role: .destructive) {
            showEndConfirmation = true
        } label: {
            controlLabel("End", systemImage: "xmark", tint: DS.Color.negative,
                         height: height, isPrimary: true, horizontal: horizontal)
        }
        .accessibilityLabel("End")
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionControlsEndButton)
    }

    private func controlLabel(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        height: CGFloat,
        isPrimary: Bool,
        horizontal: Bool = false
    ) -> some View {
        Group {
            if horizontal {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            } else {
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
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: height)
        .background(tint.opacity(DS.Opacity.overlay), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
}
