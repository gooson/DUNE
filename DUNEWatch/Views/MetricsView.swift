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
    @State private var showEmptySetConfirmation = false
    @State private var showLastSetOptions = false
    @State private var transitionTask: Task<Void, Never>?
    @State private var didInitialAppear = false
    /// Deferred input sheet trigger to prevent double-present with onAppear
    @State private var pendingInputSheet = false
    /// Cached previous sets for current exercise (avoids recompute per render)
    @State private var cachedPreviousSets: [CompletedSetData] = []

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
            refreshPreviousSetsCache()
        }
        .onAppear {
            prefillFromEntry()
            refreshPreviousSetsCache()
            // Only show input sheet on first appear, not after rest/transition
            if !didInitialAppear {
                didInitialAppear = true
                showInputSheet = true
            }
        }
        .onChange(of: pendingInputSheet) { _, shouldShow in
            if shouldShow {
                pendingInputSheet = false
                showInputSheet = true
            }
        }
        .sheet(isPresented: $showInputSheet) {
            SetInputSheet(
                weight: $weight,
                reps: $reps,
                previousSets: cachedPreviousSets
            )
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
        // P2: Empty set confirmation
        .confirmationDialog(
            "Empty Set",
            isPresented: $showEmptySetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Record Empty") {
                executeCompleteSet()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Weight and reps are both 0. Record anyway?")
        }
        // Last set options: +1 Set or Finish Exercise
        .confirmationDialog(
            "All Sets Done",
            isPresented: $showLastSetOptions,
            titleVisibility: .visible
        ) {
            Button("+1 Set") {
                addExtraSet()
            }
            Button("Finish Exercise") {
                finishCurrentExercise()
            }
        } message: {
            Text("Add another set or move on?")
        }
    }

    // MARK: - Set Entry (Redesigned)

    /// Plain VStack instead of ScrollView — crown must stay free for TabView paging.
    /// ScrollView in a non-last vertical page tab cannot receive crown events.
    private var setEntryView: some View {
        VStack(spacing: DS.Spacing.md) {
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
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Progress

    private var sessionProgressBar: some View {
        GeometryReader { geo in
            let total = workoutManager.totalExercises
            let progress = total > 0 ? Double(workoutManager.currentExerciseIndex) / Double(total) : 0

            RoundedRectangle(cornerRadius: DS.Radius.xs)
                .fill(.tertiary)
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DS.Radius.xs)
                        .fill(DS.Color.positive)
                        .frame(width: geo.size.width * progress, height: 3)
                }
        }
        .frame(height: 3)
        .padding(.bottom, DS.Spacing.xxs)
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        VStack(spacing: DS.Spacing.xs) {
            if let entry = workoutManager.currentEntry {
                Text(entry.exerciseName)
                    .font(DS.Typography.exerciseName)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)

                Text("Set \(workoutManager.currentSetIndex + 1) of \(workoutManager.effectiveTotalSets)")
                    .font(DS.Typography.tileSubtitle)
                    .foregroundStyle(.secondary)

                // Set progress dots
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(0..<workoutManager.effectiveTotalSets, id: \.self) { i in
                        Circle()
                            .fill(dotColor(for: i))
                            .frame(width: DS.Spacing.md, height: DS.Spacing.md)
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
            return DS.Color.positive
        } else if setIndex == workoutManager.currentSetIndex {
            return DS.Color.positive.opacity(0.4)
        } else {
            return .secondary.opacity(0.3)
        }
    }

    // MARK: - Input Card (Tap to Edit)

    private var inputCard: some View {
        Button {
            showInputSheet = true
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("\(weight, specifier: "%.1f")")
                        .font(DS.Typography.metricValue)
                    Text("kg")
                        .font(DS.Typography.tileSubtitle)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: DS.Spacing.xs) {
                    Text("\u{00d7}")
                        .font(DS.Typography.tileSubtitle)
                        .foregroundStyle(.secondary)
                    Text("\(reps)")
                        .font(DS.Typography.metricValue)
                    Text("reps")
                        .font(DS.Typography.tileSubtitle)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(DS.Color.positive)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(DS.Color.positive.opacity(DS.Opacity.border))
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(DS.Spacing.sm)
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
        .tint(DS.Color.positive)
    }

    // MARK: - Heart Rate

    private var heartRateDisplay: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(DS.Color.heartRate)

            if workoutManager.heartRate > 0 {
                Text("\(Int(workoutManager.heartRate).formattedWithSeparator) bpm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, DS.Spacing.xxs)
    }

    // MARK: - Next Exercise Transition

    private var nextExerciseTransition: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("Next Exercise")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            if let next = nextEntryName {
                Text(next)
                    .font(DS.Typography.exerciseName)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .tint(DS.Color.positive)
        }
        .onAppear {
            transitionTask?.cancel()
            transitionTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                workoutManager.advanceToNextExercise()
                showNextExercise = false
                prefillFromEntry()
                WKInterfaceDevice.current().play(.notification)
                pendingInputSheet = true
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

    /// Refresh cached previous sets for the current exercise.
    private func refreshPreviousSetsCache() {
        let idx = workoutManager.currentExerciseIndex
        guard idx >= 0, idx < workoutManager.completedSetsData.count else {
            cachedPreviousSets = []
            return
        }
        cachedPreviousSets = workoutManager.completedSetsData[idx]
    }

    private func completeSet() {
        // P2: Validate empty set
        if weight <= 0, reps <= 0 {
            showEmptySetConfirmation = true
            return
        }
        executeCompleteSet()
    }

    private func executeCompleteSet() {
        let wasLastSet = workoutManager.isLastSet

        workoutManager.completeSet(weight: weight > 0 ? weight : nil, reps: reps > 0 ? reps : nil)
        refreshPreviousSetsCache()

        // Haptic on set completion
        WKInterfaceDevice.current().play(.success)

        if wasLastSet {
            // Offer +1 Set option instead of auto-finishing
            showLastSetOptions = true
        } else {
            // Go to rest first, input sheet comes after rest
            showRestTimer = true
        }
    }

    private func finishCurrentExercise() {
        if workoutManager.isLastExercise {
            WKInterfaceDevice.current().play(.success)
            workoutManager.end()
        } else {
            WKInterfaceDevice.current().play(.start)
            showNextExercise = true
        }
    }

    private func addExtraSet() {
        workoutManager.addExtraSet()
        WKInterfaceDevice.current().play(.start)
        showRestTimer = true
    }

    private func handleRestComplete() {
        showRestTimer = false
        workoutManager.advanceToNextSet()
        prefillFromEntry()

        // Haptic on rest complete → defer input sheet to avoid double-present
        WKInterfaceDevice.current().play(.notification)
        pendingInputSheet = true
    }
}
