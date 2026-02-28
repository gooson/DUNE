import SwiftUI
import SwiftData

/// Single-exercise workout session — Watch-style one-set-at-a-time flow.
/// Flow: Input (weight/reps) → Complete Set → Rest → Input → ... → Finish
struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue
    @State private var viewModel: WorkoutSessionViewModel
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var sessionTimerTask: Task<Void, Never>?
    @State private var shareImage: UIImage?
    @State private var showingShareSheet = false
    @State private var savedRecord: ExerciseRecord?
    @State private var savedIntensity: WorkoutIntensityResult?
    @FocusState private var isInputFieldFocused: Bool

    // Set-by-set flow state
    @State private var currentSetIndex = 0
    @State private var showRestTimer = false
    @State private var showLastSetOptions = false
    @State private var showEndConfirmation = false
    @State private var restTimerCompleted = 0
    @State private var setCompleteCount = 0

    @Query private var exerciseRecords: [ExerciseRecord]

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .kg
    }

    let exercise: ExerciseDefinition
    private let draftToRestore: WorkoutSessionDraft?

    private var totalSets: Int { viewModel.sets.count }
    /// Max dots before truncating the progress indicator (UI width limit)
    private let maxProgressDots = 12

    init(exercise: ExerciseDefinition) {
        self.exercise = exercise
        let draft = WorkoutSessionDraft.load()
        if let draft, draft.exerciseDefinition.id == exercise.id {
            let vm = WorkoutSessionViewModel(exercise: exercise)
            vm.restoreFromDraft(draft)
            self._viewModel = State(initialValue: vm)
            self.draftToRestore = draft
        } else {
            self._viewModel = State(initialValue: WorkoutSessionViewModel(exercise: exercise))
            self.draftToRestore = nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: progress + timer
            topBar

            // Main content area — switches between input and rest
            ZStack {
                if showRestTimer {
                    restTimerContent
                        .transition(.opacity)
                } else {
                    setInputContent
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showRestTimer)

            // Bottom action button
            bottomAction
        }
        .background { DetailWaveBackground() }
        .sensoryFeedback(.success, trigger: setCompleteCount)
        .sensoryFeedback(.success, trigger: restTimerCompleted)
        .navigationTitle(exercise.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    weightUnitRaw = (weightUnit == .kg ? WeightUnit.lb : WeightUnit.kg).rawValue
                } label: {
                    Text(weightUnit.displayName.uppercased())
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Color.activity.opacity(0.15), in: Capsule())
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { saveWorkout() }
                    .disabled(viewModel.completedSetCount == 0)
                    .fontWeight(.semibold)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputFieldFocused = false
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("workout-keyboard-done-button")
            }
        }
        .onAppear {
            viewModel.loadPreviousSets(from: exerciseRecords, weightUnit: weightUnit)
            if draftToRestore != nil {
                WorkoutSessionViewModel.clearDraft()
            }
            // Skip already-completed sets (draft restore)
            skipToFirstIncompleteSet()
            startSessionTimer()
        }
        .onDisappear {
            sessionTimerTask?.cancel()
            sessionTimerTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel.saveDraft()
            }
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) { saveWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save and finish this workout?")
        }
        .sheet(isPresented: $showLastSetOptions) {
            allSetsDoneSheet
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
        .alert("Validation Error", isPresented: .init(
            get: { viewModel.validationError != nil },
            set: { if !$0 { viewModel.validationError = nil } }
        )) {
            Button("OK") { viewModel.validationError = nil }
        } message: {
            Text(viewModel.validationError ?? "")
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: { dismiss() }) {
            WorkoutCompletionSheet(
                shareImage: shareImage,
                exerciseName: exercise.localizedName,
                setCount: viewModel.completedSetCount,
                autoIntensity: savedIntensity,
                onDismiss: { selectedRPE in
                    if let rpe = selectedRPE, (1...10).contains(rpe) {
                        savedRecord?.rpe = rpe
                    }
                    dismiss()
                }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Set progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalSets, id: \.self) { i in
                    Circle()
                        .fill(dotColor(for: i))
                        .frame(width: 10, height: 10)
                }

                // Animated extra dot placeholder
                if totalSets < maxProgressDots {
                    Circle()
                        .strokeBorder(.tertiary, lineWidth: 1)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, DS.Spacing.sm)

            HStack {
                Text("Set \(currentSetIndex + 1) of \(totalSets)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formattedElapsedTime)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DS.Spacing.lg)

            Divider()
        }
    }

    private func dotColor(for index: Int) -> Color {
        if viewModel.sets.indices.contains(index), viewModel.sets[index].isCompleted {
            return DS.Color.activity
        } else if index == currentSetIndex {
            return DS.Color.activity.opacity(0.4)
        } else {
            return .gray.opacity(0.2)
        }
    }

    // MARK: - Set Input Content

    private var setInputContent: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            // Exercise info
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: exercise.resolvedActivityType.iconName)
                    .font(.largeTitle)
                    .foregroundStyle(exercise.resolvedActivityType.color)

                Text(exercise.localizedName)
                    .font(.title2.weight(.bold))

                // Previous set info
                if let prev = viewModel.previousSetInfo(for: currentSetIndex + 1) {
                    previousBadge(prev)
                }
            }

            // Weight / Reps input
            currentSetInputFields

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    @ViewBuilder
    private func previousBadge(_ prev: PreviousSetInfo) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
            if let w = prev.weight, let r = prev.reps {
                Text("\(weightUnit.fromKg(w), specifier: "%.1f")\(weightUnit.displayName) × \(r.formattedWithSeparator)")
                    .font(.caption)
            } else if let r = prev.reps {
                Text("\(r.formattedWithSeparator) reps")
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThinMaterial, in: Capsule())
    }

    @ViewBuilder
    private var currentSetInputFields: some View {
        if viewModel.sets.indices.contains(currentSetIndex) {
            let setBinding = $viewModel.sets[currentSetIndex]

            VStack(spacing: DS.Spacing.lg) {
                switch exercise.inputType {
                case .setsRepsWeight:
                    weightRepsInput(set: setBinding)
                case .setsReps:
                    repsOnlyInput(set: setBinding)
                case .durationDistance:
                    durationDistanceInput(set: setBinding)
                case .durationIntensity:
                    durationIntensityInput(set: setBinding)
                case .roundsBased:
                    roundsBasedInput(set: setBinding)
                }
            }
        }
    }

    // MARK: - Input Fields (by type)

    private func weightRepsInput(set: Binding<EditableSet>) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Weight section — large display + ± buttons
            stepperField(
                label: weightUnit.displayName.uppercased(),
                value: set.weight,
                placeholder: "0",
                keyboardType: .decimalPad,
                stepButtons: [
                    ("-2.5", { adjustDecimalValue(set.weight, by: -2.5, min: 0, max: 500) }),
                    ("+2.5", { adjustDecimalValue(set.weight, by: 2.5, min: 0, max: 500) })
                ]
            )

            Divider()
                .padding(.horizontal, DS.Spacing.xl)

            // Reps section — large display + ± buttons
            stepperField(
                label: "REPS",
                value: set.reps,
                placeholder: "0",
                keyboardType: .numberPad,
                stepButtons: [
                    ("-1", { adjustIntValue(set.reps, by: -1, min: 0, max: 100) }),
                    ("+1", { adjustIntValue(set.reps, by: 1, min: 0, max: 100) })
                ]
            )
        }
    }

    private func repsOnlyInput(set: Binding<EditableSet>) -> some View {
        stepperField(
            label: "REPS",
            value: set.reps,
            placeholder: "0",
            keyboardType: .numberPad,
            stepButtons: [
                ("-1", { adjustIntValue(set.reps, by: -1, min: 0, max: 100) }),
                ("+1", { adjustIntValue(set.reps, by: 1, min: 0, max: 100) })
            ]
        )
    }

    private func durationDistanceInput(set: Binding<EditableSet>) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            stepperField(
                label: "MINUTES",
                value: set.duration,
                placeholder: "0",
                keyboardType: .numberPad,
                stepButtons: [
                    ("-1", { adjustIntValue(set.duration, by: -1, min: 0, max: 480) }),
                    ("+1", { adjustIntValue(set.duration, by: 1, min: 0, max: 480) })
                ]
            )

            Divider()
                .padding(.horizontal, DS.Spacing.xl)

            stepperField(
                label: "KM",
                value: set.distance,
                placeholder: "0",
                keyboardType: .decimalPad,
                stepButtons: [
                    ("-0.1", { adjustDecimalValue(set.distance, by: -0.1, min: 0, max: 100) }),
                    ("+0.1", { adjustDecimalValue(set.distance, by: 0.1, min: 0, max: 100) })
                ]
            )
        }
    }

    private func durationIntensityInput(set: Binding<EditableSet>) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            stepperField(
                label: "MINUTES",
                value: set.duration,
                placeholder: "0",
                keyboardType: .numberPad,
                stepButtons: [
                    ("-1", { adjustIntValue(set.duration, by: -1, min: 0, max: 480) }),
                    ("+1", { adjustIntValue(set.duration, by: 1, min: 0, max: 480) })
                ]
            )

            Divider()
                .padding(.horizontal, DS.Spacing.xl)

            stepperField(
                label: "INTENSITY",
                value: set.intensity,
                placeholder: "1-10",
                keyboardType: .numberPad,
                stepButtons: [
                    ("-1", { adjustIntValue(set.intensity, by: -1, min: 1, max: 10) }),
                    ("+1", { adjustIntValue(set.intensity, by: 1, min: 1, max: 10) })
                ]
            )
        }
    }

    private func roundsBasedInput(set: Binding<EditableSet>) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            stepperField(
                label: "ROUNDS",
                value: set.reps,
                placeholder: "0",
                keyboardType: .numberPad,
                stepButtons: [
                    ("-1", { adjustIntValue(set.reps, by: -1, min: 0, max: 100) }),
                    ("+1", { adjustIntValue(set.reps, by: 1, min: 0, max: 100) })
                ]
            )

            Divider()
                .padding(.horizontal, DS.Spacing.xl)

            stepperField(
                label: "SECONDS",
                value: set.duration,
                placeholder: "0",
                keyboardType: .numberPad,
                stepButtons: [
                    ("-10", { adjustIntValue(set.duration, by: -10, min: 0, max: 3600) }),
                    ("+10", { adjustIntValue(set.duration, by: 10, min: 0, max: 3600) })
                ]
            )
        }
    }

    // MARK: - Stepper Field

    private func stepperField(
        label: String,
        value: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType,
        stepButtons: [(String, () -> Void)]
    ) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(keyboardType)
                .submitLabel(.done)
                .focused($isInputFieldFocused)
                .onSubmit { isInputFieldFocused = false }
                .foregroundStyle(DS.Color.activity)

            HStack(spacing: DS.Spacing.sm) {
                ForEach(Array(stepButtons.enumerated()), id: \.offset) { _, button in
                    Button(action: button.1) {
                        Text(button.0)
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
        }
    }

    // MARK: - Value Adjusters

    private func adjustDecimalValue(_ binding: Binding<String>, by delta: Double, min minVal: Double, max maxVal: Double) {
        let trimmed = binding.wrappedValue.trimmingCharacters(in: .whitespaces)
        let current = trimmed.isEmpty ? 0 : (Double(trimmed) ?? 0)
        let newValue = Swift.max(minVal, Swift.min(maxVal, current + delta))
        // Remove trailing .0 for whole numbers
        if newValue.truncatingRemainder(dividingBy: 1) == 0 {
            binding.wrappedValue = String(format: "%.0f", newValue)
        } else {
            binding.wrappedValue = String(format: "%.1f", newValue)
        }
    }

    private func adjustIntValue(_ binding: Binding<String>, by delta: Int, min minVal: Int, max maxVal: Int) {
        let trimmed = binding.wrappedValue.trimmingCharacters(in: .whitespaces)
        let current = trimmed.isEmpty ? 0 : (Int(trimmed) ?? 0)
        let newValue = Swift.max(minVal, Swift.min(maxVal, current + delta))
        binding.wrappedValue = String(newValue)
    }

    // MARK: - Rest Timer Content

    private var restTimerContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            Text("Rest")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            // Completed set summary
            if viewModel.sets.indices.contains(currentSetIndex),
               viewModel.sets[currentSetIndex].isCompleted {
                completedSetSummary
            }

            // Circular timer
            circularTimer

            // Controls
            restControls

            Spacer()
        }
    }

    @State private var restSecondsRemaining: Int = 0
    @State private var restTotalSeconds: Int = 90
    @State private var restTimerTask: Task<Void, Never>?

    private var completedSetSummary: some View {
        let set = viewModel.sets[currentSetIndex]
        let formattedReps = Int(set.reps).map(\.formattedWithSeparator) ?? set.reps
        return HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DS.Color.activity)
            if !set.weight.isEmpty, !set.reps.isEmpty {
                Text("\(set.weight)\(weightUnit.displayName) × \(formattedReps) reps")
                    .font(.headline)
            } else if !set.reps.isEmpty {
                Text("\(formattedReps) reps")
                    .font(.headline)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var circularTimer: some View {
        ZStack {
            Circle()
                .stroke(.tertiary, lineWidth: 8)

            Circle()
                .trim(from: 0, to: restProgress)
                .stroke(DS.Color.activity, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: restSecondsRemaining)

            VStack(spacing: DS.Spacing.xxs) {
                Text(restTimeString)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(width: 180, height: 180)
    }

    private var restProgress: Double {
        guard restTotalSeconds > 0 else { return 0 }
        return Double(restSecondsRemaining) / Double(restTotalSeconds)
    }

    private var restTimeString: String {
        let mins = restSecondsRemaining / 60
        let secs = restSecondsRemaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var restControls: some View {
        HStack(spacing: DS.Spacing.md) {
            Button {
                let maxRestSeconds = 3600 // 1 hour cap
                guard restTotalSeconds + 30 <= maxRestSeconds else { return }
                restSecondsRemaining += 30
                restTotalSeconds += 30
            } label: {
                Text("+30s")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Button {
                finishRest()
            } label: {
                Text("Skip")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.activity)

            Button {
                showEndConfirmation = true
            } label: {
                Text("End")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    // MARK: - Bottom Action

    private var bottomAction: some View {
        VStack(spacing: 0) {
            Divider()
            if !showRestTimer {
                Button {
                    completeCurrentSet()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Set")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.lg)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.activity)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
            }
        }
    }

    // MARK: - All Sets Done Sheet

    private var allSetsDoneSheet: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(DS.Color.activity)

                Text("All Sets Done")
                    .font(.headline)
            }
            .padding(.top, DS.Spacing.md)

            VStack(spacing: DS.Spacing.sm) {
                Button {
                    showLastSetOptions = false
                    addExtraSet()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("+1 Set")
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(DS.Color.activity)

                Button {
                    showLastSetOptions = false
                    saveWorkout()
                } label: {
                    Text("Finish Workout")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.negative)
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    // MARK: - Actions

    private func completeCurrentSet() {
        isInputFieldFocused = false
        guard viewModel.sets.indices.contains(currentSetIndex) else { return }

        // Mark set as completed
        viewModel.sets[currentSetIndex].isCompleted = true
        setCompleteCount += 1

        let isLast = currentSetIndex >= totalSets - 1

        if isLast {
            showLastSetOptions = true
        } else {
            startRest()
        }
    }

    private func startRest() {
        restTotalSeconds = 30
        restSecondsRemaining = 30
        showRestTimer = true
        startRestCountdown()
    }

    private func startRestCountdown() {
        restTimerTask?.cancel()
        restTimerTask = Task {
            while restSecondsRemaining > 0, !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch { break }
                guard !Task.isCancelled else { return }
                restSecondsRemaining -= 1
            }
            guard !Task.isCancelled else { return }
            finishRest()
        }
    }

    private func finishRest() {
        restTimerTask?.cancel()
        restTimerTask = nil
        showRestTimer = false
        restTimerCompleted += 1

        // Advance to next set
        currentSetIndex += 1

        // Prefill from previous set's values
        prefillCurrentSet()
    }

    private func addExtraSet() {
        viewModel.addSet(weightUnit: weightUnit)
        startRest()
    }

    private func prefillCurrentSet() {
        guard viewModel.sets.indices.contains(currentSetIndex) else { return }

        // If set already has values from previous session, keep them
        let set = viewModel.sets[currentSetIndex]
        if !set.weight.isEmpty || !set.reps.isEmpty { return }

        // Otherwise copy from last completed set
        if let lastCompleted = viewModel.sets.prefix(currentSetIndex).last(where: \.isCompleted) {
            viewModel.sets[currentSetIndex].weight = lastCompleted.weight
            viewModel.sets[currentSetIndex].reps = lastCompleted.reps
            viewModel.sets[currentSetIndex].duration = lastCompleted.duration
            viewModel.sets[currentSetIndex].distance = lastCompleted.distance
            viewModel.sets[currentSetIndex].intensity = lastCompleted.intensity
        }
    }

    private func skipToFirstIncompleteSet() {
        if let idx = viewModel.sets.firstIndex(where: { !$0.isCompleted }) {
            currentSetIndex = idx
        }
    }

    // MARK: - Save

    private func saveWorkout() {
        isInputFieldFocused = false
        guard let record = viewModel.createValidatedRecord(weightUnit: weightUnit) else { return }

        // Auto intensity calculation before insert
        let intensityResult = calculateAutoIntensity(for: record)
        record.autoIntensityRaw = intensityResult?.rawScore
        savedIntensity = intensityResult

        let shareData = buildShareData(from: record)
        shareImage = WorkoutShareService.renderShareImage(data: shareData, weightUnit: weightUnit)

        modelContext.insert(record)
        savedRecord = record
        viewModel.didFinishSaving()
        WorkoutSessionViewModel.clearDraft()

        // Fire-and-forget HealthKit write
        if !record.isFromHealthKit {
            let input = WorkoutWriteInput(
                startDate: record.date,
                duration: record.duration,
                category: exercise.category,
                exerciseName: exercise.name,
                estimatedCalories: record.estimatedCalories,
                isFromHealthKit: record.isFromHealthKit
            )
            Task {
                do {
                    let hkID = try await WorkoutWriteService().saveWorkout(input)
                    record.healthKitWorkoutID = hkID
                } catch {
                    AppLogger.healthKit.error("Failed to write workout to HealthKit: \(error.localizedDescription)")
                }
            }
        }

        if shareImage != nil {
            showingShareSheet = true
        } else {
            dismiss()
        }
    }

    private func calculateAutoIntensity(for record: ExerciseRecord) -> WorkoutIntensityResult? {
        let service = WorkoutIntensityService()

        let currentInput = buildIntensityInput(from: record)

        // History: same exercise, last 30 sessions, oldest-first (Correction #156)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let history: [IntensitySessionInput] = exerciseRecords
            .filter { $0.exerciseDefinitionID == exercise.id && $0.date >= thirtyDaysAgo }
            .sorted { $0.date < $1.date }
            .map { buildIntensityInput(from: $0) }

        // Estimated 1RM for strength exercises
        var estimated1RM: Double?
        if exercise.inputType == .setsRepsWeight {
            let oneRMSessions = history.map { session in
                OneRMSessionInput(
                    date: session.date,
                    sets: session.sets.map { OneRMSetInput(weight: $0.weight, reps: $0.reps) }
                )
            }
            estimated1RM = OneRMEstimationService().analyze(sessions: oneRMSessions).currentBest
        }

        return service.calculateIntensity(
            current: currentInput,
            history: history,
            estimated1RM: estimated1RM
        )
    }

    private func buildIntensityInput(from record: ExerciseRecord) -> IntensitySessionInput {
        IntensitySessionInput(
            date: record.date,
            exerciseType: exercise.inputType,
            sets: record.completedSets.map { set in
                IntensitySetInput(
                    weight: set.weight,
                    reps: set.reps,
                    duration: set.duration,
                    distance: set.distance,
                    manualIntensity: set.intensity,
                    setType: set.setType
                )
            },
            rpe: record.rpe
        )
    }

    private func buildShareData(from record: ExerciseRecord) -> WorkoutShareData {
        let input = ExerciseRecordShareInput(
            exerciseType: record.exerciseType,
            date: record.date,
            duration: elapsedSeconds,
            bestCalories: record.bestCalories,
            completedSets: record.completedSets.map { set in
                ExerciseRecordShareInput.SetInput(
                    setNumber: set.setNumber,
                    weight: set.weight,
                    reps: set.reps,
                    duration: set.duration,
                    distance: set.distance,
                    setType: set.setType
                )
            }
        )
        return WorkoutShareService.buildShareData(from: input)
    }

    private var formattedElapsedTime: String {
        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func startSessionTimer() {
        sessionTimerTask?.cancel()
        sessionTimerTask = Task {
            while !Task.isCancelled {
                elapsedSeconds = Date().timeIntervalSince(viewModel.sessionStartTime)
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch { break }
            }
        }
    }
}
