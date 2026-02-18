import SwiftUI
import WatchKit

/// Center page of SessionPagingView: Set entry with Digital Crown weight,
/// +/- reps, Complete button, and real-time HR display.
struct MetricsView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var showRestTimer = false
    @State private var showNextExercise = false
    @State private var showEndConfirmation = false
    @State private var transitionTask: Task<Void, Never>?

    var body: some View {
        Group {
            if showRestTimer {
                RestTimerView(
                    duration: currentRestDuration,
                    onComplete: handleRestComplete,
                    onSkip: handleRestComplete,
                    onEnd: { showEndConfirmation = true }
                )
            } else if showNextExercise {
                nextExerciseTransition
            } else {
                setEntryView
            }
        }
        .onChange(of: workoutManager.currentExerciseIndex) { _, _ in
            prefillFromEntry()
        }
        .onAppear {
            prefillFromEntry()
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) {
                showRestTimer = false
                showNextExercise = false
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

    // MARK: - Set Entry

    private var setEntryView: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Progress bar
                sessionProgressBar

                // Exercise name + set counter
                exerciseHeader

                Divider()

                // Weight input (Digital Crown + buttons)
                weightInput

                // Reps input (+/-)
                repsInput

                // Complete Set button
                completeButton

                // Heart rate
                heartRateDisplay
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Progress

    private var sessionProgressBar: some View {
        GeometryReader { geo in
            let total = workoutManager.totalExercises
            let progress = total > 0 ? Double(workoutManager.currentExerciseIndex) / Double(total) : 0

            RoundedRectangle(cornerRadius: 2)
                .fill(.tertiary)
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.green)
                        .frame(width: geo.size.width * progress, height: 3)
                }
        }
        .frame(height: 3)
        .padding(.bottom, 4)
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        VStack(spacing: 2) {
            if let entry = workoutManager.currentEntry {
                Text(entry.exerciseName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("Set \(workoutManager.currentSetIndex + 1) / \(entry.defaultSets)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Set progress dots
                HStack(spacing: 3) {
                    ForEach(0..<entry.defaultSets, id: \.self) { i in
                        Circle()
                            .fill(dotColor(for: i))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }

    private func dotColor(for setIndex: Int) -> Color {
        let completedCount = workoutManager.completedSetsData.indices.contains(workoutManager.currentExerciseIndex)
            ? workoutManager.completedSetsData[workoutManager.currentExerciseIndex].count
            : 0

        if setIndex < completedCount {
            return .green
        } else if setIndex == workoutManager.currentSetIndex {
            return .green.opacity(0.4)
        } else {
            return .gray.opacity(0.3)
        }
    }

    // MARK: - Weight Input

    private var weightInput: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Weight")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(weight, specifier: "%.1f") kg")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.green)
            }

            // +/- buttons for precise adjustment
            HStack(spacing: 12) {
                Button {
                    if weight >= 5 { weight -= 5 }
                } label: {
                    Text("-5")
                        .font(.caption2.weight(.medium))
                        .frame(width: 32)
                }
                .buttonStyle(.bordered)
                .tint(.gray)

                Button {
                    if weight >= 2.5 { weight -= 2.5 }
                } label: {
                    Text("-2.5")
                        .font(.caption2.weight(.medium))
                        .frame(width: 36)
                }
                .buttonStyle(.bordered)
                .tint(.gray)

                Button {
                    if weight <= 497.5 { weight += 2.5 }
                } label: {
                    Text("+2.5")
                        .font(.caption2.weight(.medium))
                        .frame(width: 36)
                }
                .buttonStyle(.bordered)
                .tint(.gray)

                Button {
                    if weight <= 495 { weight += 5 }
                } label: {
                    Text("+5")
                        .font(.caption2.weight(.medium))
                        .frame(width: 32)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
        .focusable()
        .digitalCrownRotation($weight, from: 0, through: 500, by: 2.5, sensitivity: .medium)
    }

    // MARK: - Reps Input

    private var repsInput: some View {
        HStack {
            Text("Reps")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()

            HStack(spacing: 8) {
                Button {
                    if reps > 0 { reps -= 1 }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Text("\(reps)")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.green)
                    .frame(minWidth: 24)

                Button {
                    if reps < 100 { reps += 1 }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button {
            completeSet()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle")
                Text("Complete Set")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .padding(.top, 4)
    }

    // MARK: - Heart Rate

    private var heartRateDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.red)

            if workoutManager.heartRate > 0 {
                Text("\(Int(workoutManager.heartRate)) bpm")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text("--")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Next Exercise Transition

    private var nextExerciseTransition: some View {
        VStack(spacing: 12) {
            Text("Next Exercise")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let next = nextEntryName {
                Text(next)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .tint(.green)
        }
        .onAppear {
            transitionTask?.cancel()
            transitionTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                workoutManager.advanceToNextExercise()
                showNextExercise = false
            }
        }
        .onDisappear {
            transitionTask?.cancel()
            transitionTask = nil
        }
    }

    private var nextEntryName: String? {
        guard let snapshot = workoutManager.templateSnapshot else { return nil }
        let nextIndex = workoutManager.currentExerciseIndex + 1
        guard nextIndex < snapshot.entries.count else { return nil }
        return snapshot.entries[nextIndex].exerciseName
    }

    // MARK: - Actions

    private func prefillFromEntry() {
        guard let entry = workoutManager.currentEntry else { return }

        // Use previous set's weight/reps if available, otherwise fall back to template default
        if let lastSet = workoutManager.lastCompletedSetForCurrentExercise {
            weight = lastSet.weight ?? entry.defaultWeightKg ?? 0
            reps = lastSet.reps ?? entry.defaultReps
        } else {
            weight = entry.defaultWeightKg ?? 0
            reps = entry.defaultReps
        }
    }

    private var currentRestDuration: TimeInterval {
        workoutManager.currentEntry?.restDuration ?? 30
    }

    private func completeSet() {
        workoutManager.completeSet(weight: weight > 0 ? weight : nil, reps: reps > 0 ? reps : nil)

        if workoutManager.isLastSet {
            if workoutManager.isLastExercise {
                // All done — end workout
                workoutManager.end()
            } else {
                // Show next exercise transition
                showNextExercise = true
            }
        } else {
            // Show rest timer, then advance to next set
            showRestTimer = true
        }
    }

    private func handleRestComplete() {
        showRestTimer = false
        workoutManager.advanceToNextSet()
        prefillFromEntry()
    }
}
