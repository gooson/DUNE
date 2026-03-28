import SwiftUI
import WatchKit

/// Center page of SessionPagingView: Hierarchical set display with
/// tap-to-edit input sheet. Crown is free for scrolling.
struct MetricsView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.appTheme) private var theme

    @State private var weight: Double = 0
    @State private var reps: Int = WatchSetInputPolicy.defaultReps
    @State private var durationMinutes: Int = 1
    /// Start date of the current duration-intensity set (live timer).
    @State private var setTimerStart: Date?
    /// Auto-estimated RPE for the just-completed set (shown on rest timer).
    @State private var estimatedRPE: Double?
    @State private var showInputSheet = false
    @State private var showRestTimer = false
    @State private var showNextExercise = false
    @State private var showEndConfirmation = false
    @State private var showLastSetOptions = false
    @State private var transitionTask: Task<Void, Never>?
    @State private var didInitialAppear = false
    /// Deferred input sheet trigger to prevent double-present with onAppear
    @State private var pendingInputSheet = false
    /// Cached previous sets for current exercise (avoids recompute per render)
    @State private var cachedPreviousSets: [CompletedSetData] = []
    /// Last rest timer total used within this exercise (for carry-forward)
    @State private var lastRestTimerTotal: TimeInterval?

    /// Resolved inputType for the current exercise entry.
    private var currentInputType: ExerciseInputType {
        workoutManager.currentEntry?.inputTypeRaw
            .flatMap(ExerciseInputType.init(rawValue:)) ?? .setsRepsWeight
    }

    var body: some View {
        Group {
            if showRestTimer {
                RestTimerView(
                    duration: currentRestDuration,
                    onComplete: { total in handleRestComplete(timerTotal: total) },
                    onSkip: { total in handleRestComplete(timerTotal: total) },
                    onEnd: { showEndConfirmation = true },
                    estimatedRPE: estimatedRPE,
                    onRPEAdjusted: { estimatedRPE = $0 }
                )
            } else if showNextExercise {
                nextExerciseTransition
            } else {
                setEntryView
            }
        }
        .onChange(of: workoutManager.currentExerciseIndex) { _, _ in
            lastRestTimerTotal = nil
            estimatedRPE = nil
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
                inputType: currentInputType,
                weight: $weight,
                reps: $reps,
                durationMinutes: $durationMinutes,
                previousSets: cachedPreviousSets
            )
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout") {
                flushEstimatedRPE()
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
        // Last set options: +1 Set or Finish Exercise
        .confirmationDialog(
            "All Sets Done",
            isPresented: $showLastSetOptions,
            titleVisibility: .visible
        ) {
            Button("+1 Set") {
                addExtraSet()
            }
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionMetricsLastSetAdd)
            Button("Finish Exercise", role: .destructive) {
                finishCurrentExercise()
            }
            .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionMetricsLastSetFinish)
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

            // Input card — adapts to inputType
            inputCard

            // Complete Set button (large touch target)
            completeButton

            // Heart rate (secondary)
            heartRateDisplay
        }
        .padding(.horizontal, DS.Spacing.md)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionMetricsScreen)
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
        let isDuration = currentInputType == .durationIntensity
        return Button {
            if !isDuration { showInputSheet = true }
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                switch currentInputType {
                case .durationIntensity:
                    durationInputCardContent
                case .setsReps:
                    repsOnlyInputCardContent
                case .setsRepsWeight, .durationDistance, .roundsBased:
                    weightRepsInputCardContent
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
                if !isDuration {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(DS.Spacing.sm)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionMetricsInputCard)
    }

    private var weightRepsInputCardContent: some View {
        Group {
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
    }

    private var repsOnlyInputCardContent: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text("\(reps)")
                .font(DS.Typography.metricValue)
            Text("reps")
                .font(DS.Typography.tileSubtitle)
                .foregroundStyle(.secondary)
        }
    }

    private var durationInputCardContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = Int(setTimerStart.map { context.date.timeIntervalSince($0) } ?? 0)
            let mins = elapsed / 60
            let secs = elapsed % 60
            Text(String(format: "%d:%02d", mins, secs))
                .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                .contentTransition(.numericText())
        }
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
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionMetricsCompleteSetButton)
    }

    // MARK: - Heart Rate

    private var heartRateDisplay: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(theme.metricHeartRate)

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
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionMetricsNextExercise)
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

        // Always clear stale timer when switching exercises/sets
        setTimerStart = nil

        let inputType = currentInputType

        if inputType == .durationIntensity {
            // Start the live timer for this set.
            setTimerStart = Date()
            return
        }

        let fallbackReps = WatchSetInputPolicy.resolvedInitialReps(
            lastSetReps: nil,
            entryDefaultReps: entry.defaultReps
        )

        if let plannedSet = workoutManager.currentPlannedSetForCurrentExercise {
            weight = plannedSet.weight ?? entry.defaultWeightKg ?? 0
            reps = WatchSetInputPolicy.resolvedInitialReps(
                lastSetReps: plannedSet.reps,
                entryDefaultReps: entry.defaultReps
            )
            return
        }

        // Use previous set's weight/reps if available, otherwise fall back to template default
        if let lastSet = workoutManager.lastCompletedSetForCurrentExercise {
            weight = lastSet.weight ?? entry.defaultWeightKg ?? 0
            reps = WatchSetInputPolicy.resolvedInitialReps(
                lastSetReps: lastSet.reps,
                entryDefaultReps: entry.defaultReps
            )
        } else {
            weight = entry.defaultWeightKg ?? 0
            reps = fallbackReps
        }
    }

    /// Priority: within-session carry-forward → template entry → global default.
    /// Watch cannot access previous-session SwiftData records inline;
    /// lastRestTimerTotal serves the same UX purpose as iOS previous-session rest.
    private var currentRestDuration: TimeInterval {
        lastRestTimerTotal
            ?? workoutManager.currentEntry?.restDuration
            ?? WatchConnectivityManager.shared.globalRestSeconds
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
        let inputType = currentInputType

        if inputType == .durationIntensity {
            guard let start = setTimerStart else {
                WKInterfaceDevice.current().play(.failure)
                return
            }
            let elapsed = Date().timeIntervalSince(start)
            guard elapsed >= 1, elapsed <= 7200 else {
                WKInterfaceDevice.current().play(.failure)
                return
            }
            executeDurationCompleteSet(elapsedSeconds: elapsed)
            return
        }

        guard WatchSetInputPolicy.isValidForCompletion(reps: reps) else {
            reps = WatchSetInputPolicy.defaultReps
            showInputSheet = true
            WKInterfaceDevice.current().play(.failure)
            return
        }
        executeCompleteSet()
    }

    private func executeCompleteSet() {
        let wasLastSet = workoutManager.isLastSet

        // Capture prior sets BEFORE appending current (avoids including self in 1RM estimate)
        let priorSets = workoutManager.completedSetsData.indices.contains(workoutManager.currentExerciseIndex)
            ? workoutManager.completedSetsData[workoutManager.currentExerciseIndex]
            : []

        workoutManager.completeSet(weight: weight > 0 ? weight : nil, reps: reps > 0 ? reps : nil, rpe: nil)
        refreshPreviousSetsCache()

        // Auto-estimate RPE for the just-completed set
        estimatedRPE = WatchRPEEstimator.estimateRPE(weight: weight, reps: reps, completedSets: priorSets)

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

    private func executeDurationCompleteSet(elapsedSeconds: TimeInterval) {
        let wasLastSet = workoutManager.isLastSet

        workoutManager.completeSet(weight: nil, reps: nil, duration: elapsedSeconds, rpe: nil)
        refreshPreviousSetsCache()
        setTimerStart = nil

        estimatedRPE = nil

        WKInterfaceDevice.current().play(.success)

        if wasLastSet {
            showLastSetOptions = true
        } else {
            showRestTimer = true
        }
    }

    /// Flush any pending estimated RPE to the last completed set.
    private func flushEstimatedRPE() {
        if let rpe = estimatedRPE {
            workoutManager.recordSetRPE(rpe)
        }
        estimatedRPE = nil
    }

    private func finishCurrentExercise() {
        flushEstimatedRPE()
        if workoutManager.isLastExercise {
            WKInterfaceDevice.current().play(.success)
            workoutManager.end()
        } else {
            WKInterfaceDevice.current().play(.start)
            showNextExercise = true
        }
    }

    private func addExtraSet() {
        flushEstimatedRPE()
        workoutManager.addExtraSet()
        WKInterfaceDevice.current().play(.start)
        showRestTimer = true
    }

    private func handleRestComplete(timerTotal: TimeInterval) {
        workoutManager.recordRestDuration(timerTotal)
        lastRestTimerTotal = timerTotal

        // Save estimated/adjusted RPE to the just-completed set before advancing
        flushEstimatedRPE()

        showRestTimer = false
        workoutManager.advanceToNextSet()
        prefillFromEntry()

        // Haptic on rest complete → defer input sheet to avoid double-present
        WKInterfaceDevice.current().play(.notification)
        pendingInputSheet = true
    }
}
