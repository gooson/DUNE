import SwiftUI
import SwiftData

struct CompoundWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue
    @State private var viewModel: CompoundWorkoutViewModel
    @State private var transitionTimer = RestTimerViewModel()
    @State private var setTimer = RestTimerViewModel()
    @State private var saveCount = 0
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var sessionTimerTask: Task<Void, Never>?
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?

    @Query private var exerciseRecords: [ExerciseRecord]

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .kg
    }

    let config: CompoundWorkoutConfig

    init(config: CompoundWorkoutConfig) {
        self.config = config
        self._viewModel = State(initialValue: CompoundWorkoutViewModel(config: config))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    roundIndicator
                    exerciseTabs
                    currentExerciseSection
                    actionButtons
                    workoutSummary
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, timerVisible ? 140 : 80)
            }

            // Rest timer overlay
            if setTimer.isRunning {
                RestTimerView(timer: setTimer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Transition timer overlay (between exercises)
            if viewModel.isTransitioning {
                transitionOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DS.Animation.snappy, value: setTimer.isRunning)
        .animation(DS.Animation.snappy, value: viewModel.isTransitioning)
        .sensoryFeedback(.success, trigger: saveCount)
        .sensoryFeedback(.success, trigger: setTimer.completionCount)
        .navigationTitle(config.mode.displayName)
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
                Button("Finish") {
                    saveAll()
                }
                .disabled(viewModel.totalCompletedSets == 0)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            viewModel.loadPreviousSets(from: exerciseRecords)
            startSessionTimer()
        }
        .onDisappear {
            sessionTimerTask?.cancel()
            sessionTimerTask = nil
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
                exerciseName: config.mode.displayName,
                setCount: viewModel.totalCompletedSets,
                onDismiss: { dismiss() }
            )
            .presentationDetents([.medium])
        }
    }

    private var timerVisible: Bool {
        setTimer.isRunning || viewModel.isTransitioning
    }

    // MARK: - Round Indicator

    private var roundIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: config.mode == .superset ? "arrow.triangle.2.circlepath" : "repeat")
                .foregroundStyle(DS.Color.activity)

            Text("Round \(viewModel.currentRound) / \(config.totalRounds)")
                .font(.subheadline.weight(.semibold))

            Spacer()

            // Session elapsed time
            Text(formattedElapsedTime)
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Exercise Tabs

    private var exerciseTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(config.exercises.indices, id: \.self) { index in
                    exerciseTab(index: index)
                }
            }
        }
    }

    private func exerciseTab(index: Int) -> some View {
        let exercise = config.exercises[index]
        let isCurrent = index == viewModel.currentExerciseIndex
        let vm = viewModel.exerciseViewModels[index]
        let completed = vm.completedSetCount

        return Button {
            withAnimation(DS.Animation.snappy) {
                viewModel.goToExercise(at: index)
            }
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                Text(exercise.localizedName)
                    .font(.caption.weight(isCurrent ? .bold : .regular))
                    .lineLimit(1)
                if completed > 0 {
                    Text("\(completed) sets")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                isCurrent ? DS.Color.activity.opacity(0.15) : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .foregroundStyle(isCurrent ? DS.Color.activity : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current Exercise Section

    private var currentExerciseSection: some View {
        let vm = viewModel.currentViewModel
        let exercise = viewModel.currentExercise

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Exercise header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: WorkoutSummary.iconName(for: exercise.name))
                    .font(.title2)
                    .foregroundStyle(DS.Color.activity)
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

            // Set list for current exercise
            setListFor(vm: vm, exercise: exercise)
        }
    }

    private func setListFor(vm: WorkoutSessionViewModel, exercise: ExerciseDefinition) -> some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: DS.Spacing.sm) {
                Text("SET")
                    .frame(width: 24)
                Text("PREV")
                    .frame(width: 56, alignment: .leading)
                columnHeaders(for: exercise)
                Spacer()
                Text("")
                    .frame(width: 28)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
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
                    onComplete: {
                        let completed = vm.toggleSetCompletion(at: index)
                        if completed {
                            setTimer.start()
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

    @ViewBuilder
    private func columnHeaders(for exercise: ExerciseDefinition) -> some View {
        switch exercise.inputType {
        case .setsRepsWeight:
            HStack(spacing: DS.Spacing.xs) {
                Text(weightUnit.displayName.uppercased()).frame(maxWidth: 70)
                Text("REPS").frame(maxWidth: 60)
            }
        case .setsReps:
            Text("REPS").frame(maxWidth: 80)
        case .durationDistance:
            HStack(spacing: DS.Spacing.xs) {
                Text("MIN").frame(maxWidth: 60)
                Text("KM").frame(maxWidth: 70)
            }
        case .durationIntensity:
            HStack(spacing: DS.Spacing.xs) {
                Text("MIN").frame(maxWidth: 60)
                Text("INT").frame(maxWidth: 60)
            }
        case .roundsBased:
            HStack(spacing: DS.Spacing.xs) {
                Text("REPS").frame(maxWidth: 60)
                Text("SEC").frame(maxWidth: 60)
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

            // Next exercise button
            if !viewModel.isComplete {
                Button {
                    withAnimation(DS.Animation.snappy) {
                        viewModel.advanceToNextExercise()
                        if config.restBetweenExercises > 0 {
                            transitionTimer.start(seconds: config.restBetweenExercises)
                        } else {
                            viewModel.finishTransition()
                        }
                    }
                } label: {
                    let nextLabel = viewModel.isLastExerciseInRound
                        ? "Next Round →"
                        : "Next Exercise →"
                    Label(nextLabel, systemImage: "arrow.right.circle.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Color.activity, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Workout Summary

    private var workoutSummary: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Summary")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ForEach(config.exercises.indices, id: \.self) { index in
                let exercise = config.exercises[index]
                let vm = viewModel.exerciseViewModels[index]
                HStack {
                    Text(exercise.localizedName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(vm.completedSetCount) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Transition Overlay

    private var transitionOverlay: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Up Next")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(viewModel.currentExercise.localizedName)
                .font(.title3.weight(.semibold))

            if transitionTimer.isRunning {
                Text(transitionTimer.formattedTime)
                    .font(DS.Typography.cardScore)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                ProgressView(value: transitionTimer.progress)
                    .tint(DS.Color.activity)
            }

            HStack(spacing: DS.Spacing.lg) {
                if transitionTimer.isRunning {
                    Button {
                        transitionTimer.addTime(30)
                    } label: {
                        Text("+30s")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }

                Button {
                    transitionTimer.stop()
                    viewModel.finishTransition()
                } label: {
                    Text("Start")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.activity)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
    }

    // MARK: - Save

    private func saveAll() {
        let records = viewModel.createAllRecords(weightUnit: weightUnit)
        guard !records.isEmpty else { return }

        // Build share data from the first (primary) record
        if let primary = records.first {
            let input = ExerciseRecordShareInput(
                exerciseType: config.mode.displayName,
                date: primary.date,
                duration: elapsedSeconds,
                bestCalories: records.compactMap(\.bestCalories).reduce(0, +),
                completedSets: records.flatMap { record in
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
            )
            let data = WorkoutShareService.buildShareData(from: input)
            shareImage = WorkoutShareService.renderShareImage(data: data, weightUnit: weightUnit)
        }

        for record in records {
            modelContext.insert(record)
        }
        viewModel.didFinishSaving()
        saveCount += 1

        // Fire-and-forget HealthKit write per record (non-blocking)
        for record in records where !record.isFromHealthKit {
            let matchedExercise = config.exercises.first { $0.id == record.exerciseDefinitionID }
            let input = WorkoutWriteInput(
                startDate: record.date,
                duration: record.duration,
                category: matchedExercise?.category ?? .strength,
                exerciseName: record.exerciseType,
                estimatedCalories: record.estimatedCalories,
                isFromHealthKit: record.isFromHealthKit
            )
            Task {
                do {
                    let hkID = try await WorkoutWriteService().saveWorkout(input)
                    record.healthKitWorkoutID = hkID
                } catch {
                    AppLogger.healthKit.error("Failed to write compound workout to HealthKit: \(error.localizedDescription)")
                }
            }
        }

        if shareImage != nil {
            showingShareSheet = true
        } else {
            dismiss()
        }
    }

    // MARK: - Timer

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
                } catch {
                    break
                }
            }
        }
    }
}
