import SwiftUI
import SwiftData

/// Redesigned Activity tab with weekly summary chart, today's metrics, and recent workouts.
struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @State private var showingAddExercise = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                if viewModel.isLoading && viewModel.weeklyExerciseMinutes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Weekly Summary Hero Chart
                    WeeklySummaryChartView(
                        exerciseData: viewModel.weeklyExerciseMinutes,
                        stepsData: viewModel.weeklySteps
                    )

                    // Today's Metrics
                    todaySection

                    // Recent Workouts
                    ExerciseListSection(workouts: viewModel.recentWorkouts)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
            }
            .padding()
        }
        .background {
            LinearGradient(
                colors: [DS.Color.activity.opacity(0.03), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExercise = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("activity-add-button")
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseSheetWrapper(modelContext: modelContext)
        }
        .navigationDestination(for: HealthMetric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: AllDataDestination.self) { destination in
            AllDataView(category: destination.category)
        }
        .refreshable {
            await viewModel.loadActivityData()
        }
        .task {
            await viewModel.loadActivityData()
        }
        .navigationTitle("Activity")
    }

    // MARK: - Today Section

    @ViewBuilder
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Today")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Spacing.md),
                    GridItem(.flexible(), spacing: DS.Spacing.md),
                ],
                spacing: DS.Spacing.md
            ) {
                if let exercise = viewModel.todayExercise {
                    NavigationLink(value: exercise) {
                        MetricCardView(metric: exercise)
                    }
                    .buttonStyle(.plain)
                }

                if let steps = viewModel.todaySteps {
                    NavigationLink(value: steps) {
                        MetricCardView(metric: steps)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Add Exercise Sheet Wrapper

/// Thin wrapper to create ExerciseViewModel for the add sheet.
private struct AddExerciseSheetWrapper: View {
    let modelContext: ModelContext
    @State private var exerciseVM = ExerciseViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var saveCount = 0

    var body: some View {
        NavigationStack {
            Form {
                if let error = exerciseVM.validationError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                DatePicker(
                    "Date & Time",
                    selection: $exerciseVM.selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )

                Picker("Type", selection: $exerciseVM.newExerciseType) {
                    ForEach(ExerciseViewModel.exerciseTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }

                LabeledContent("Duration") {
                    Stepper(
                        "\(Int(exerciseVM.newDuration / 60)) min",
                        value: $exerciseVM.newDuration,
                        in: (5 * 60)...(300 * 60),
                        step: 5 * 60
                    )
                }

                TextField("Calories (kcal)", text: $exerciseVM.newCalories)
                    .keyboardType(.numberPad)

                TextField("Distance (m)", text: $exerciseVM.newDistance)
                    .keyboardType(.decimalPad)

                TextField("Memo", text: $exerciseVM.newMemo)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let record = exerciseVM.createValidatedRecord() {
                            modelContext.insert(record)
                            saveCount += 1
                            exerciseVM.resetForm()
                            dismiss()
                        }
                    }
                    .disabled(exerciseVM.newExerciseType.isEmpty)
                }
            }
        }
        .sensoryFeedback(.success, trigger: saveCount)
        .onAppear {
            if exerciseVM.newExerciseType.isEmpty {
                exerciseVM.newExerciseType = ExerciseViewModel.exerciseTypes[0]
            }
        }
    }
}

#Preview {
    ActivityView()
        .modelContainer(for: ExerciseRecord.self, inMemory: true)
}
