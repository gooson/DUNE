import SwiftUI
import WatchKit

/// Center page of SessionPagingView: Hierarchical set display with
/// tap-to-edit input sheet. Crown is free for scrolling.
struct MetricsView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.appTheme) private var theme

    @State private var weight: Double = 0
    @State private var usesAddedWeight = false
    @State private var sessionWeightOverride: Double?
    @State private var nextSetReductionKg: Double?
    @State private var reps: Int = WatchSetInputPolicy.defaultReps
    @State private var durationMinutes: Int = 1
    /// Start date of the current duration-intensity set (live timer).
    @State private var setTimerStart: TimeInterval?
    /// Auto-estimated RPE for the just-completed set (shown on rest timer).
    @State private var estimatedRPE: Double?
    @State private var showInputSheet = false
    @State private var showRestTimer = false
    @State private var showNextExercise = false
    @State private var showLastSetOptions = false
    @State private var showLastSetRPEInput = false
    @State private var pendingLastSetRPEInput = false
    @State private var lastSetRPEInput = 8.0
    @State private var didInitialAppear = false
    /// Deferred input sheet trigger to prevent double-present with onAppear
    @State private var pendingInputSheet = false
    /// Cached previous sets for current exercise (avoids recompute per render)
    @State private var cachedPreviousSets: [CompletedSetData] = []
    /// Last rest timer total used within this exercise (for carry-forward)
    @State private var lastRestTimerTotal: TimeInterval?

    /// Resolved inputType for the current exercise entry.
    private var currentInputType: ExerciseInputType {
        TemplateExerciseProfile.normalizedInputTypeRaw(workoutManager.currentEntry?.inputTypeRaw)
            .flatMap(ExerciseInputType.init(rawValue:)) ?? .setsRepsWeight
    }

    var body: some View {
        Group {
            if showRestTimer {
                RestTimerView(
                    duration: currentRestDuration,
                    onComplete: { total in handleRestComplete(timerTotal: total) },
                    onSkip: { total in handleRestComplete(timerTotal: total) },
                    estimatedRPE: estimatedRPE,
                    onRPEAdjusted: { adjusted in
                        estimatedRPE = adjusted
                        workoutManager.recordSetRPE(adjusted, source: "user")
                    }
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
            sessionWeightOverride = nil
            nextSetReductionKg = nil
            prefillFromEntry()
            refreshPreviousSetsCache()
        }
        .onAppear {
            prefillFromEntry()
            refreshPreviousSetsCache()
            // Only show input sheet on first appear, not after rest/transition
            if !didInitialAppear {
                didInitialAppear = true
                showInputSheet = currentInputType != .durationIntensity
            }
        }
        .onChange(of: pendingInputSheet) { _, shouldShow in
            if shouldShow {
                pendingInputSheet = false
                showInputSheet = currentInputType != .durationIntensity
            }
        }
        .onChange(of: showLastSetOptions) { wasPresented, isPresented in
            if wasPresented, !isPresented, pendingLastSetRPEInput {
                pendingLastSetRPEInput = false
                showLastSetRPEInput = true
            }
        }
        .sheet(isPresented: $showInputSheet) {
            SetInputSheet(
                inputType: currentInputType,
                weight: $weight,
                reps: $reps,
                durationMinutes: $durationMinutes,
                usesAddedWeight: $usesAddedWeight,
                previousSets: cachedPreviousSets,
                suggestedWeightKg: nextSetReductionKg,
                onWeightEdited: { edited in
                    sessionWeightOverride = edited
                    nextSetReductionKg = nil
                }
            )
        }
        .sheet(isPresented: $showLastSetRPEInput, onDismiss: {
            showLastSetOptions = true
        }) {
            lastSetRPESheet
        }
        // Last set options: +1 Set or Finish Exercise
        .confirmationDialog(
            "All Sets Done",
            isPresented: $showLastSetOptions,
            titleVisibility: .visible
        ) {
            if estimatedRPE == nil {
                Button("Rate RPE") { presentLastSetRPEInput() }
                    .accessibilityIdentifier("watch-last-set-rpe-action")
            } else {
                Button("Confirm RPE") { presentLastSetRPEInput() }
                    .accessibilityIdentifier("watch-last-set-rpe-action")
            }
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

    private func presentLastSetRPEInput() {
        lastSetRPEInput = estimatedRPE ?? 8
        pendingLastSetRPEInput = true
    }

    private var lastSetRPESheet: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("RPE \(RPELevel.format(lastSetRPEInput))")
                .font(.headline.monospacedDigit())

            HStack(spacing: DS.Spacing.md) {
                Button {
                    lastSetRPEInput = max(RPELevel.range.lowerBound, lastSetRPEInput - RPELevel.step)
                } label: {
                    Image(systemName: "minus")
                }
                .accessibilityIdentifier("watch-last-set-rpe-decrement")

                Button {
                    lastSetRPEInput = min(RPELevel.range.upperBound, lastSetRPEInput + RPELevel.step)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("watch-last-set-rpe-increment")
            }
            .buttonStyle(.bordered)

            Button("Confirm RPE") {
                estimatedRPE = lastSetRPEInput
                workoutManager.recordSetRPE(lastSetRPEInput, source: "user")
                showLastSetRPEInput = false
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("watch-last-set-rpe-confirm")
        }
        .padding(DS.Spacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch-last-set-rpe-sheet")
    }

    // MARK: - Set Entry (Redesigned)

    /// Plain VStack instead of ScrollView — crown must stay free for TabView paging.
    /// ScrollView in a non-last vertical page tab cannot receive crown events.
    private var setEntryView: some View {
        VStack(spacing: DS.Spacing.md) {
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

            }
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
                    if usesAddedWeight { weightRepsInputCardContent } else { repsOnlyInputCardContent }
                case .roundsBased:
                    repsOnlyInputCardContent
                    durationInputCardContent
                case .setsRepsWeight, .durationDistance:
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
            let elapsed = Int(setTimerStart.map { max(0, workoutManager.activeElapsedTime(at: context.date) - $0) } ?? 0)
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

            if let next = proposedExerciseName {
                Text(next)
                    .font(DS.Typography.exerciseName)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            Button {
                // finishCurrentExercise already advanced the index;
                // just dismiss overlay and start the exercise
                showNextExercise = false
                prefillFromEntry()
                WKInterfaceDevice.current().play(.notification)
                pendingInputSheet = true
            } label: {
                Text("Start")
                    .frame(maxWidth: .infinity)
            }
            .tint(DS.Color.positive)

            Button {
                let hasNext = workoutManager.skipExercise()
                if hasNext {
                    // Overlay stays visible with updated exercise name
                    WKInterfaceDevice.current().play(.click)
                } else {
                    showNextExercise = false
                    WKInterfaceDevice.current().play(.success)
                    workoutManager.end()
                }
            } label: {
                Text("Skip")
                    .frame(maxWidth: .infinity)
            }
            .tint(.gray)
        }
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.sessionMetricsNextExercise)
    }

    /// Name of the exercise currently proposed in the transition overlay.
    /// After advanceToNextExercise or skipExercise, currentExerciseIndex already points
    /// to the next candidate, so we read the current (not +1) entry.
    private var proposedExerciseName: String? {
        guard let snapshot = workoutManager.templateSnapshot else { return nil }
        let idx = workoutManager.currentExerciseIndex
        guard idx < snapshot.entries.count else { return nil }
        return snapshot.entries[idx].exerciseName
    }

    // MARK: - Actions

    private func prefillFromEntry() {
        guard let entry = workoutManager.currentEntry else { return }

        // Always clear stale timer when switching exercises/sets
        setTimerStart = nil

        let inputType = currentInputType

        defer {
            if inputType == .setsReps || inputType == .setsRepsWeight {
                if let sessionWeightOverride { weight = sessionWeightOverride }
            } else {
                weight = 0
            }
            usesAddedWeight = inputType == .setsReps && weight > 0
        }

        if inputType == .durationIntensity {
            // Start the live timer for this set.
            setTimerStart = workoutManager.activeElapsedTime
            return
        }

        if inputType == .roundsBased { setTimerStart = workoutManager.activeElapsedTime }

        let fallbackReps = WatchSetInputPolicy.resolvedInitialReps(
            lastSetReps: nil,
            entryDefaultReps: entry.defaultReps
        )

        if let plannedSet = workoutManager.currentPlannedSetForCurrentExercise {
            weight = WatchSetInputPolicy.resolvedWeight(
                previousWeight: plannedSet.weight, defaultWeight: entry.defaultWeightKg, hasPreviousSet: true
            )
            reps = WatchSetInputPolicy.resolvedInitialReps(
                lastSetReps: plannedSet.plannedReps ?? plannedSet.reps,
                entryDefaultReps: entry.defaultReps
            )
            return
        }

        // Use previous set's weight/reps if available, otherwise fall back to template default
        if let lastSet = workoutManager.lastCompletedSetForCurrentExercise {
            weight = WatchSetInputPolicy.resolvedWeight(
                previousWeight: lastSet.weight, defaultWeight: entry.defaultWeightKg, hasPreviousSet: true
            )
            reps = WatchSetInputPolicy.resolvedInitialReps(
                lastSetReps: lastSet.reps,
                entryDefaultReps: entry.defaultReps
            )
        } else {
            weight = WatchSetInputPolicy.resolvedWeight(
                previousWeight: nil, defaultWeight: entry.defaultWeightKg, hasPreviousSet: false
            )
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
            let elapsed = max(0, workoutManager.activeElapsedTime - start)
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

        let recordedWeight = WatchSetInputPolicy.completedWeight(weight, inputType: currentInputType)
        let duration = currentInputType == .roundsBased
            ? setTimerStart.map { max(1, min(7200, workoutManager.activeElapsedTime - $0)) }
            : nil
        workoutManager.completeSet(weight: recordedWeight, reps: reps > 0 ? reps : nil, duration: duration, rpe: nil)
        nextSetReductionKg = nil
        refreshPreviousSetsCache()

        // Auto-estimate RPE for the just-completed set
        estimatedRPE = WatchRPEEstimator.estimateRPE(weight: recordedWeight ?? 0, reps: reps, completedSets: priorSets)
        if let estimatedRPE {
            workoutManager.recordSetRPE(estimatedRPE, source: "estimated")
        }

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
        nextSetReductionKg = nil
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

    private func clearEstimatedRPE() {
        estimatedRPE = nil
    }

    private func finishCurrentExercise() {
        clearEstimatedRPE()
        // Advance to next non-skipped exercise for the transition to display
        workoutManager.advanceToNextExercise()
        if workoutManager.isAllExercisesDone {
            WKInterfaceDevice.current().play(.success)
            workoutManager.end()
        } else {
            WKInterfaceDevice.current().play(.start)
            showNextExercise = true
        }
    }

    private func addExtraSet() {
        clearEstimatedRPE()
        workoutManager.addExtraSet()
        WKInterfaceDevice.current().play(.start)
        showRestTimer = true
    }

    private func handleRestComplete(timerTotal: TimeInterval) {
        workoutManager.recordRestDuration(timerTotal)
        lastRestTimerTotal = timerTotal

        // Save estimated/adjusted RPE to the just-completed set before advancing
        clearEstimatedRPE()

        showRestTimer = false
        workoutManager.advanceToNextSet()
        nextSetReductionKg = WatchSetInputPolicy.reducedWeight(
            after: workoutManager.lastCompletedSetForCurrentExercise,
            nextSetTypeRaw: workoutManager.currentPlannedSetForCurrentExercise?.setTypeRaw,
            equipmentRaw: workoutManager.currentEntry?.equipment,
            progressionIncrementKg: workoutManager.currentEntry.flatMap {
                WatchConnectivityManager.shared.exerciseInfo(for: $0.exerciseDefinitionID)?.progressionIncrementKg
            },
            inputType: currentInputType
        )
        prefillFromEntry()

        // Haptic on rest complete → defer input sheet to avoid double-present
        WKInterfaceDevice.current().play(.notification)
        pendingInputSheet = true
    }
}
