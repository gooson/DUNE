import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue
    @State private var viewModel: WorkoutSessionViewModel
    @State private var timer = RestTimerViewModel()
    @State private var saveCount = 0
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var sessionTimerTask: Task<Void, Never>?
    @State private var shareImage: UIImage?
    @State private var showingShareSheet = false

    @Query private var exerciseRecords: [ExerciseRecord]

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .kg
    }

    let exercise: ExerciseDefinition
    private let draftToRestore: WorkoutSessionDraft?

    init(exercise: ExerciseDefinition) {
        self.exercise = exercise
        // Check if there's a draft for this exercise
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
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    exerciseHeader
                    previousSessionBanner
                    setList
                    addSetButton
                    memoSection
                    calorieEstimate
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, timer.isRunning ? 140 : 80)
            }

            // Rest timer overlay (Correction Log #28: use overlay, not VStack child)
            if timer.isRunning {
                RestTimerView(timer: timer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DS.Animation.snappy, value: timer.isRunning)
        .sensoryFeedback(.success, trigger: saveCount)
        .sensoryFeedback(.success, trigger: timer.completionCount)
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
                Button("Done") {
                    saveWorkout()
                }
                .disabled(viewModel.completedSetCount == 0)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            viewModel.loadPreviousSets(from: exerciseRecords)
            if draftToRestore != nil {
                WorkoutSessionViewModel.clearDraft()
            }
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
                onDismiss: { dismiss() }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
                        Text(exercise.equipment.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Session elapsed time
                Text(formattedElapsedTime)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.top, DS.Spacing.sm)
    }

    private var formattedElapsedTime: String {
        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Previous Session Banner

    @ViewBuilder
    private var previousSessionBanner: some View {
        if !viewModel.previousSets.isEmpty {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Previous: \(previousSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    private var previousSummary: String {
        viewModel.previousSets.summary()
    }

    // MARK: - Set List

    private var setList: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: DS.Spacing.sm) {
                Text("SET")
                    .frame(width: 24)
                Text("PREV")
                    .frame(width: 56, alignment: .leading)
                columnHeaders
                Spacer()
                Text("")
                    .frame(width: 28)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xs)

            // Set rows
            ForEach(viewModel.sets.indices, id: \.self) { index in
                SetRowView(
                    editableSet: $viewModel.sets[index],
                    inputType: exercise.inputType,
                    previousSet: viewModel.previousSetInfo(for: viewModel.sets[index].setNumber),
                    weightUnit: weightUnit,
                    onComplete: {
                        let completed = viewModel.toggleSetCompletion(at: index)
                        if completed {
                            timer.start()
                        }
                    },
                    onFillFromPrevious: viewModel.previousSetInfo(for: viewModel.sets[index].setNumber) != nil ? {
                        viewModel.fillSetFromPrevious(at: index, weightUnit: weightUnit)
                    } : nil
                )
                .contextMenu {
                    // Set type selection
                    Menu {
                        ForEach([SetType.warmup, .working, .drop, .failure], id: \.self) { type in
                            Button {
                                viewModel.sets[index].setType = type
                            } label: {
                                Label {
                                    Text(type.displayName)
                                } icon: {
                                    if viewModel.sets[index].setType == type {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Set Type", systemImage: "tag")
                    }

                    Divider()

                    Button(role: .destructive) {
                        withAnimation(DS.Animation.snappy) {
                            viewModel.removeSet(at: index)
                        }
                    } label: {
                        Label("Delete Set", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var columnHeaders: some View {
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

    // MARK: - Add Set Buttons

    private var addSetButton: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                withAnimation(DS.Animation.snappy) {
                    viewModel.addSet(weightUnit: weightUnit)
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

            if viewModel.hasCompletedSet {
                Button {
                    withAnimation(DS.Animation.snappy) {
                        viewModel.repeatLastCompletedSet()
                    }
                } label: {
                    Label("Repeat", systemImage: "arrow.2.squarepath")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, DS.Spacing.md)
                        .padding(.horizontal, DS.Spacing.lg)
                        .background(
                            Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Memo

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Memo")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("Optional notes...", text: $viewModel.memo, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }

    // MARK: - Calorie Estimate

    private var calorieEstimate: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            if let cal = viewModel.estimatedCalories {
                Text("~\(Int(cal)) kcal (estimated)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Calorie estimate will appear after completing sets")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Save

    private func saveWorkout() {
        guard let record = viewModel.createValidatedRecord(weightUnit: weightUnit) else { return }

        // Build share data before inserting (while we still have ViewModel state)
        let shareData = buildShareData(from: record)
        shareImage = WorkoutShareService.renderShareImage(data: shareData, weightUnit: weightUnit)

        modelContext.insert(record)
        viewModel.didFinishSaving()
        WorkoutSessionViewModel.clearDraft()
        saveCount += 1

        // Fire-and-forget HealthKit write (non-blocking)
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
