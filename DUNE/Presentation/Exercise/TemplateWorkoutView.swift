import SwiftUI
import SwiftData

/// Sequential template workout — records each exercise individually.
/// Flow: Exercise 1 → Save → Exercise 2 → Save → ... → Workout Complete
struct TemplateWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme

    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue
    @State private var viewModel: TemplateWorkoutViewModel
    @State private var restTimer = RestTimerViewModel()
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var sessionTimerTask: Task<Void, Never>?
    @State private var showingCompletionSheet = false
    @State private var shareImage: UIImage?
    @State private var savedRecords: [ExerciseRecord] = []
    @State private var effortSuggestion: EffortSuggestion?
    @State private var saveCount = 0
    @State private var showTransition = false

    @Query private var exerciseRecords: [ExerciseRecord]

    private let intensityService = WorkoutIntensityService()

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .kg
    }

    let config: TemplateWorkoutConfig

    init(config: TemplateWorkoutConfig) {
        self.config = config
        self._viewModel = State(initialValue: TemplateWorkoutViewModel(config: config))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    exerciseProgressHeader
                    currentExerciseContent
                    actionButtons
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, restTimer.isRunning ? 140 : 80)
            }

            if restTimer.isRunning {
                RestTimerView(timer: restTimer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showTransition {
                transitionOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background { DetailWaveBackground() }
        .animation(DS.Animation.snappy, value: restTimer.isRunning)
        .animation(DS.Animation.snappy, value: showTransition)
        .sensoryFeedback(.success, trigger: saveCount)
        .sensoryFeedback(.success, trigger: restTimer.completionCount)
        .englishNavigationTitle(config.templateName)
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
                if viewModel.isAllDone {
                    Button("Done") { finishWorkout() }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.hasAnyCompleted)
                }
            }
        }
        .onAppear {
            restoreFromDraftIfNeeded()
            viewModel.prefillFromTemplateDefaults(weightUnit: weightUnit)
            viewModel.loadPreviousSets(from: exerciseRecords, weightUnit: weightUnit)
            startSessionTimer()
        }
        .onDisappear {
            sessionTimerTask?.cancel()
            sessionTimerTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                viewModel.saveDraft()
            }
        }
        .alert("Validation Error", isPresented: .init(
            get: { viewModel.validationError != nil },
            set: { if !$0 { viewModel.validationError = nil } }
        )) {
            Button("OK") { viewModel.validationError = nil }
        } message: {
            Text(viewModel.validationError ?? "")
        }
        .sheet(isPresented: $showingCompletionSheet, onDismiss: { dismiss() }) {
            WorkoutCompletionSheet(
                shareImage: shareImage,
                exerciseName: config.templateName,
                setCount: viewModel.totalCompletedSets,
                effortSuggestion: effortSuggestion,
                onDismiss: { effort in
                    if let effort, (1...10).contains(effort) {
                        for record in savedRecords {
                            record.rpe = effort
                        }
                    }
                    dismiss()
                }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Exercise Progress Header

    private var exerciseProgressHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "list.clipboard")
                    .foregroundStyle(DS.Color.activity)

                Text(String(localized: "Exercise \(viewModel.currentExerciseIndex + 1) of \(viewModel.totalExercises)"))
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(formattedElapsedTime)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(DS.Color.textSecondary)
                    .contentTransition(.numericText())
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            // Exercise tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(config.exercises.indices, id: \.self) { index in
                        exerciseTab(index: index)
                    }
                }
            }
        }
    }

    private func exerciseTab(index: Int) -> some View {
        let exercise = config.exercises[index]
        let status = viewModel.exerciseStatuses[index]
        let isCurrent = index == viewModel.currentExerciseIndex

        return Button {
            withAnimation(DS.Animation.snappy) {
                viewModel.goToExercise(at: index)
                showTransition = false
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                statusIcon(for: status)
                    .font(.caption2)

                Text(exercise.localizedName)
                    .font(.caption.weight(isCurrent ? .bold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                tabBackground(status: status, isCurrent: isCurrent),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .foregroundStyle(tabForeground(status: status, isCurrent: isCurrent))
        }
        .buttonStyle(.plain)
        .disabled(status == .completed)
    }

    @ViewBuilder
    private func statusIcon(for status: TemplateExerciseStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
        case .inProgress:
            Image(systemName: "circle.fill")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .skipped:
            Image(systemName: "forward.circle")
        }
    }

    private func tabBackground(status: TemplateExerciseStatus, isCurrent: Bool) -> Color {
        switch status {
        case .completed: DS.Color.activity.opacity(0.15)
        case .inProgress where isCurrent: DS.Color.activity.opacity(0.15)
        case .inProgress: Color.secondary.opacity(0.08)
        case .skipped: Color.secondary.opacity(0.05)
        case .pending: Color.secondary.opacity(0.08)
        }
    }

    private func tabForeground(status: TemplateExerciseStatus, isCurrent: Bool) -> Color {
        switch status {
        case .completed: DS.Color.activity
        case .inProgress where isCurrent: DS.Color.activity
        case .inProgress: theme.sandColor
        case .skipped: DS.Color.textSecondary
        case .pending: theme.sandColor
        }
    }

    // MARK: - Current Exercise Content

    private var currentExerciseContent: some View {
        let vm = viewModel.currentViewModel
        let exercise = viewModel.currentExercise

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Exercise header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: exercise.resolvedActivityType.iconName)
                    .font(.title2)
                    .foregroundStyle(exercise.resolvedActivityType.color)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(exercise.localizedName)
                        .font(.title3.weight(.semibold))
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                            Text(muscle.displayName)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(DS.Color.activity.opacity(0.15), in: Capsule())
                                .foregroundStyle(DS.Color.activity)
                        }
                    }
                }
                Spacer()
            }

            // Set list
            setList(vm: vm, exercise: exercise)
        }
    }

    private func setList(vm: WorkoutSessionViewModel, exercise: ExerciseDefinition) -> some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: DS.Spacing.sm) {
                Text("SET")
                    .frame(width: 24)
                Text("PREV")
                    .frame(width: 56, alignment: .leading)
                ExerciseSetColumnHeaders(exercise: exercise, weightUnit: weightUnit)
                Spacer()
                Text("")
                    .frame(width: 28)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(DS.Color.textSecondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xs)

            ForEach(vm.sets.indices, id: \.self) { index in
                SetRowView(
                    editableSet: Binding(
                        get: { vm.sets[index] },
                        set: { vm.sets[index] = $0 }
                    ),
                    inputType: exercise.inputType,
                    previousSet: vm.previousSetInfo(for: vm.sets[index].setNumber),
                    weightUnit: weightUnit,
                    cardioUnit: exercise.cardioSecondaryUnit,
                    onComplete: {
                        let completed = vm.toggleSetCompletion(at: index)
                        if completed {
                            restTimer.start(seconds: Int(WorkoutSettingsStore.shared.restSeconds))
                        }
                    },
                    onFillFromPrevious: vm.previousSetInfo(for: vm.sets[index].setNumber) != nil ? {
                        vm.fillSetFromPrevious(at: index, weightUnit: weightUnit)
                    } : nil
                )
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation(DS.Animation.snappy) {
                            vm.removeSet(at: index)
                        }
                    } label: {
                        Label("Delete Set", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Add set to current exercise
            Button {
                withAnimation(DS.Animation.snappy) {
                    viewModel.currentViewModel.addSet(weightUnit: weightUnit)
                }
            } label: {
                Label("Add Set", systemImage: "plus.circle.fill")
                    .font(.body.weight(.medium))
                    .foregroundStyle(DS.Color.activity)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        DS.Color.activity.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                    )
            }
            .buttonStyle(.plain)

            // Complete current exercise
            Button {
                completeCurrentExercise()
            } label: {
                Label("Complete Exercise", systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Color.activity, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentViewModel.completedSetCount == 0 || viewModel.isSaving)

            // Skip exercise
            if !viewModel.isAllDone {
                Button {
                    skipCurrentExercise()
                } label: {
                    Text("Skip Exercise")
                        .font(.body.weight(.medium))
                        .foregroundStyle(DS.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Transition Overlay

    private var transitionOverlay: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(DS.Color.activity)

            Text("Up Next")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

            Text(viewModel.currentExercise.localizedName)
                .font(.title3.weight(.semibold))

            HStack(spacing: DS.Spacing.xs) {
                ForEach(viewModel.currentExercise.primaryMuscles, id: \.self) { muscle in
                    Text(muscle.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Color.activity.opacity(0.15), in: Capsule())
                        .foregroundStyle(DS.Color.activity)
                }
            }

            Button {
                withAnimation(DS.Animation.snappy) {
                    showTransition = false
                }
            } label: {
                Text("Start")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.activity)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
    }

    // MARK: - Actions

    private func completeCurrentExercise() {
        let exercise = viewModel.currentExercise
        guard let record = viewModel.createRecordForCurrent(weightUnit: weightUnit) else { return }

        modelContext.insert(record)
        WorkoutHealthKitWriter.write(record: record, exercise: exercise)
        savedRecords.append(record)
        viewModel.didFinishSaving()
        saveCount += 1

        if viewModel.isAllDone {
            finishWorkout()
        } else {
            viewModel.advanceToNext()
            showTransition = true
        }
    }

    private func skipCurrentExercise() {
        withAnimation(DS.Animation.snappy) {
            viewModel.skipCurrent()
            if viewModel.isAllDone {
                if viewModel.hasAnyCompleted {
                    finishWorkout()
                }
            }
        }
    }

    private func finishWorkout() {
        TemplateWorkoutViewModel.clearDraft()
        guard !savedRecords.isEmpty else {
            dismiss()
            return
        }

        // Build share data from all saved records
        let totalCalories = savedRecords.compactMap(\.bestCalories).reduce(0, +)
        let allSets = savedRecords.flatMap { record in
            record.completedSets.map { set in
                ExerciseRecordShareInput.SetInput(
                    setNumber: set.setNumber,
                    weight: set.weight,
                    reps: set.reps,
                    duration: set.duration,
                    distance: set.distance,
                    setType: set.setType
                )
            }
        }
        if let primary = savedRecords.first {
            let input = ExerciseRecordShareInput(
                exerciseType: config.templateName,
                date: primary.date,
                duration: elapsedSeconds,
                bestCalories: totalCalories > 0 ? totalCalories : nil,
                completedSets: allSets
            )
            let data = WorkoutShareService.buildShareData(from: input)
            shareImage = WorkoutShareService.renderShareImage(data: data, weightUnit: weightUnit)
        }

        // Effort suggestion from recent data
        let exerciseIDs = Set(savedRecords.compactMap(\.exerciseDefinitionID))
        let recentEfforts = exerciseRecords
            .filter { record in
                guard let id = record.exerciseDefinitionID else { return false }
                return exerciseIDs.contains(id) && record.rpe != nil
            }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .compactMap(\.rpe)
        effortSuggestion = intensityService.suggestEffort(
            autoIntensityRaw: nil,
            recentEfforts: recentEfforts
        )

        showingCompletionSheet = true
    }

    // MARK: - Timer

    private var formattedElapsedTime: String {
        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func restoreFromDraftIfNeeded() {
        guard let draft = TemplateWorkoutDraft.load() else { return }
        let configIDs = config.exercises.map(\.id)
        guard draft.exerciseIDs == configIDs else {
            TemplateWorkoutDraft.clear()
            return
        }
        viewModel.restoreFromDraft(draft)
    }

    private func startSessionTimer() {
        sessionTimerTask?.cancel()
        sessionTimerTask = Task {
            while !Task.isCancelled {
                elapsedSeconds = Date().timeIntervalSince(viewModel.sessionStartTime)
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }
            }
        }
    }
}
