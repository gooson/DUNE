import SwiftUI
import SwiftData

struct CreateTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var templateName = ""
    @State private var entries: [TemplateEntry] = []
    @State private var showingExercisePicker = false
    @State private var validationError: String?

    @Query private var customExercises: [CustomExercise]

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("e.g. Push Day, Leg Day", text: $templateName)
                        .autocorrectionDisabled()
                }

                Section {
                    ForEach($entries) { $entry in
                        entryRow(entry: $entry)
                    }
                    .onDelete { indices in
                        entries.remove(atOffsets: indices)
                    }
                    .onMove { from, to in
                        entries.move(fromOffsets: from, toOffset: to)
                    }

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                            .foregroundStyle(DS.Color.activity)
                    }
                } header: {
                    Text("Exercises (\(entries.count))")
                }

                if let error = validationError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTemplate() }
                        .fontWeight(.semibold)
                        .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty || entries.isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    library: library,
                    recentExerciseIDs: []
                ) { exercise in
                    let entry = TemplateEntry(
                        exerciseDefinitionID: exercise.id,
                        exerciseName: exercise.localizedName
                    )
                    entries.append(entry)
                }
            }
        }
    }

    private func entryRow(entry: Binding<TemplateEntry>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(entry.wrappedValue.exerciseName)
                .font(.subheadline.weight(.medium))

            HStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper(
                        "\(entry.wrappedValue.defaultSets)",
                        value: entry.defaultSets,
                        in: 1...20
                    )
                    .labelsHidden()
                    Text("\(entry.wrappedValue.defaultSets)")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .frame(width: 20)
                }

                HStack(spacing: DS.Spacing.xs) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper(
                        "\(entry.wrappedValue.defaultReps)",
                        value: entry.defaultReps,
                        in: 1...100
                    )
                    .labelsHidden()
                    Text("\(entry.wrappedValue.defaultReps)")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .frame(width: 24)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }

    private func saveTemplate() {
        let trimmed = templateName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            validationError = "Template name is required"
            return
        }
        guard trimmed.count <= 100 else {
            validationError = "Name must be 100 characters or less"
            return
        }
        guard !entries.isEmpty else {
            validationError = "Add at least one exercise"
            return
        }

        let template = WorkoutTemplate(name: trimmed, exerciseEntries: entries)
        modelContext.insert(template)
        dismiss()
    }
}
