import SwiftUI
import SwiftData

struct ExerciseView: View {
    @State private var viewModel = ExerciseViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var manualRecords: [ExerciseRecord]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.allExercises.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.allExercises.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "figure.run",
                    title: "No Exercises",
                    message: "Record your workouts or sync from Apple Health to track activity.",
                    actionTitle: "Add Exercise",
                    action: { viewModel.isShowingAddSheet = true }
                )
            } else {
                List {
                    ForEach(viewModel.allExercises) { item in
                        ExerciseRowView(item: item)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.isShowingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("exercise-add-button")
            }
        }
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            AddExerciseSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .task {
            viewModel.manualRecords = manualRecords
            await viewModel.loadHealthKitWorkouts()
        }
        .onChange(of: manualRecords) { _, newValue in
            viewModel.manualRecords = newValue
        }
        .navigationTitle("Exercise")
    }
}

// MARK: - Row

private struct ExerciseRowView: View {
    let item: ExerciseListItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.type)
                        .font(.headline)
                    if item.source == .healthKit {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                Text(item.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let cal = item.calories {
                    Text("\(Int(cal)) kcal")
                        .font(.subheadline)
                }
                Text(item.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add Sheet

private struct AddExerciseSheet: View {
    @Bindable var viewModel: ExerciseViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var saveCount = 0

    var body: some View {
        NavigationStack {
            Form {
                if let error = viewModel.validationError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                DatePicker(
                    "Date & Time",
                    selection: $viewModel.selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .accessibilityIdentifier("exercise-date-picker")

                Picker("Type", selection: $viewModel.newExerciseType) {
                    ForEach(ExerciseViewModel.exerciseTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }

                LabeledContent("Duration") {
                    Stepper(
                        "\(Int(viewModel.newDuration / 60)) min",
                        value: $viewModel.newDuration,
                        in: (5 * 60)...(300 * 60),
                        step: 5 * 60
                    )
                }

                TextField("Calories (kcal)", text: $viewModel.newCalories)
                    .keyboardType(.numberPad)

                TextField("Distance (m)", text: $viewModel.newDistance)
                    .keyboardType(.decimalPad)

                TextField("Memo", text: $viewModel.newMemo)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("exercise-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let record = viewModel.createValidatedRecord() {
                            modelContext.insert(record)
                            saveCount += 1
                            viewModel.resetForm()
                            viewModel.isShowingAddSheet = false
                        }
                    }
                    .disabled(viewModel.newExerciseType.isEmpty)
                    .accessibilityIdentifier("exercise-save-button")
                }
            }
        }
        .sensoryFeedback(.success, trigger: saveCount)
        .onAppear {
            if viewModel.newExerciseType.isEmpty {
                viewModel.newExerciseType = ExerciseViewModel.exerciseTypes[0]
            }
        }
    }
}

#Preview {
    ExerciseView()
        .modelContainer(for: ExerciseRecord.self, inMemory: true)
}
