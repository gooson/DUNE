import SwiftUI
import WatchKit

/// Center page of SessionPagingView: Hierarchical set display with
/// tap-to-edit input sheet. Crown is free for scrolling.
struct MetricsView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var showInputSheet = false
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
        .sheet(isPresented: $showInputSheet) {
            SetInputSheet(weight: $weight, reps: $reps)
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

    // MARK: - Set Entry (Redesigned)

    private var setEntryView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Progress bar
                sessionProgressBar

                // Exercise name (large)
                exerciseHeader

                // Weight × Reps — tap to edit
                inputCard

                // Complete Set button (large touch target)
                completeButton

                // Heart rate (secondary)
                heartRateDisplay
            }
            .padding(.horizontal, 8)
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
        .padding(.bottom, 2)
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        VStack(spacing: 4) {
            if let entry = workoutManager.currentEntry {
                Text(entry.exerciseName)
                    .font(.headline.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)

                Text("Set \(workoutManager.currentSetIndex + 1) of \(entry.defaultSets)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Set progress dots (larger)
                HStack(spacing: 4) {
                    ForEach(0..<entry.defaultSets, id: \.self) { i in
                        Circle()
                            .fill(dotColor(for: i))
                            .frame(width: 8, height: 8)
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

    // MARK: - Input Card (Tap to Edit)

    private var inputCard: some View {
        Button {
            showInputSheet = true
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(weight, specifier: "%.1f")")
                        .font(.system(.title3, design: .rounded).monospacedDigit().bold())
                    Text("kg")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text("×")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(reps)")
                        .font(.system(.title3, design: .rounded).monospacedDigit().bold())
                    Text("reps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.green.opacity(0.15))
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button {
            completeSet()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Complete Set")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    // MARK: - Heart Rate

    private var heartRateDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.red)

            if workoutManager.heartRate > 0 {
                Text("\(Int(workoutManager.heartRate)) bpm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text("--")
                    .font(.caption)
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
        WKInterfaceDevice.current().play(.success)

        if workoutManager.isLastSet {
            if workoutManager.isLastExercise {
                workoutManager.end()
            } else {
                showNextExercise = true
            }
        } else {
            showRestTimer = true
        }
    }

    private func handleRestComplete() {
        showRestTimer = false
        workoutManager.advanceToNextSet()
        prefillFromEntry()
    }
}
