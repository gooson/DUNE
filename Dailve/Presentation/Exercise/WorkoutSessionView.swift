import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: WorkoutSessionViewModel
    @State private var timer = RestTimerViewModel()
    @State private var saveCount = 0

    @Query private var exerciseRecords: [ExerciseRecord]

    let exercise: ExerciseDefinition

    init(exercise: ExerciseDefinition) {
        self.exercise = exercise
        self._viewModel = State(initialValue: WorkoutSessionViewModel(exercise: exercise))
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
        .navigationTitle(exercise.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
        }
        .alert("Validation Error", isPresented: .init(
            get: { viewModel.validationError != nil },
            set: { if !$0 { viewModel.validationError = nil } }
        )) {
            Button("OK") { viewModel.validationError = nil }
        } message: {
            Text(viewModel.validationError ?? "")
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
            }
        }
        .padding(.top, DS.Spacing.sm)
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
                    onComplete: {
                        let completed = viewModel.toggleSetCompletion(at: index)
                        if completed {
                            timer.start()
                        }
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.removeSet(at: index)
                    } label: {
                        Label("Delete", systemImage: "trash")
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
                Text("KG").frame(maxWidth: 70)
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

    // MARK: - Add Set Button

    private var addSetButton: some View {
        Button {
            withAnimation(DS.Animation.snappy) {
                viewModel.addSet()
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
        guard let record = viewModel.createValidatedRecord() else { return }
        modelContext.insert(record)
        saveCount += 1
        dismiss()
    }
}
