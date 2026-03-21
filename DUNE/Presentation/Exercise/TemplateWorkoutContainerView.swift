import SwiftUI
import SwiftData

/// Context for displaying template progress in the workout session.
struct TemplateExerciseInfo {
    let exerciseNumber: Int
    let totalExercises: Int
    let nextExerciseName: String?
    let templateName: String
}

/// Orchestrates sequential execution of a multi-exercise template workout.
///
/// Flow: Transition → Workout → Transition → Workout → ... → Dismiss
/// Each exercise is saved individually via `WorkoutSessionView`.
struct TemplateWorkoutContainerView: View {
    let config: TemplateWorkoutConfig

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var showTransition = true
    @State private var showEndConfirmation = false
    /// Forces new WorkoutSessionView instance when advancing exercises.
    @State private var exerciseViewID = UUID()

    private var isLastExercise: Bool {
        currentIndex >= config.exercises.count - 1
    }

    private var currentTemplateInfo: TemplateExerciseInfo {
        TemplateExerciseInfo(
            exerciseNumber: currentIndex + 1,
            totalExercises: config.exercises.count,
            nextExerciseName: isLastExercise ? nil : config.exercises[currentIndex + 1].localizedName,
            templateName: config.templateName
        )
    }

    var body: some View {
        NavigationStack {
            content
                .accessibilityIdentifier("template-workout-container-screen")
            .confirmationDialog(
                "End Template?",
                isPresented: $showEndConfirmation,
                titleVisibility: .visible
            ) {
                Button("End Template", role: .destructive) {
                    dismiss()
                }
                .accessibilityIdentifier("template-workout-container-end")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Completed exercises have been saved.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if showTransition {
            transitionView
        } else {
            workoutView
        }
    }

    private var transitionView: some View {
        ExerciseTransitionView(
            exercise: config.exercises[currentIndex],
            entry: config.templateEntries[currentIndex],
            exerciseNumber: currentIndex + 1,
            totalExercises: config.exercises.count,
            onStart: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showTransition = false
                }
            }
        )
        .englishNavigationTitle(config.templateName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showEndConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityIdentifier("template-workout-container-close")
            }
        }
    }

    private var workoutView: some View {
        let onExerciseCompleted: (() -> Void)? = isLastExercise ? nil : { advanceToNextExercise() }

        return WorkoutSessionView(
            exercise: config.exercises[currentIndex],
            defaultSetCount: config.templateEntries[currentIndex].defaultSets,
            templateEntry: config.templateEntries[currentIndex],
            templateInfo: currentTemplateInfo,
            onExerciseCompleted: onExerciseCompleted
        )
        .id(exerciseViewID)
    }

    // MARK: - Exercise Advancement

    private func advanceToNextExercise() {
        guard currentIndex < config.exercises.count - 1 else { return }
        exerciseViewID = UUID()
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex += 1
            showTransition = true
        }
    }
}
