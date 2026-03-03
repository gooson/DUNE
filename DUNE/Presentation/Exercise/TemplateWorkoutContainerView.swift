import SwiftUI
import SwiftData

/// Configuration for launching a sequential template workout.
struct TemplateWorkoutConfig: Identifiable {
    let id = UUID()
    let templateName: String
    let entries: [TemplateEntry]
    let exercises: [ExerciseDefinition]
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
            Group {
                if showTransition {
                    ExerciseTransitionView(
                        exercise: config.exercises[currentIndex],
                        entry: config.entries[currentIndex],
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
                        }
                    }
                } else {
                    WorkoutSessionView(
                        exercise: config.exercises[currentIndex],
                        defaultSetCount: config.entries[currentIndex].defaultSets,
                        templateInfo: currentTemplateInfo,
                        onExerciseCompleted: isLastExercise ? nil : advanceToNextExercise
                    )
                    .id(exerciseViewID)
                }
            }
            .confirmationDialog(
                "End Template?",
                isPresented: $showEndConfirmation,
                titleVisibility: .visible
            ) {
                Button("End Template", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Completed exercises have been saved.")
            }
        }
    }

    // MARK: - Exercise Advancement

    private func advanceToNextExercise() {
        guard currentIndex < config.exercises.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex += 1
            showTransition = true
            exerciseViewID = UUID()
        }
    }
}
