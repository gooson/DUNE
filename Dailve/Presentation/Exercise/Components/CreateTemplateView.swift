import SwiftUI
import SwiftData

// MARK: - Form Mode

enum TemplateFormMode {
    case create
    case edit(WorkoutTemplate)
}

// MARK: - TemplateFormView

struct TemplateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: TemplateFormMode

    @State private var templateName: String
    @State private var entries: [TemplateEntry]
    @State private var showingExercisePicker = false
    @State private var validationError: String?

    @Query private var customExercises: [CustomExercise]

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared

    // MARK: - Init

    /// Create mode
    init() {
        self.mode = .create
        _templateName = State(initialValue: "")
        _entries = State(initialValue: [])
    }

    /// Edit mode — prefills with existing template data
    init(template: WorkoutTemplate) {
        self.mode = .edit(template)
        _templateName = State(initialValue: template.name)
        _entries = State(initialValue: template.exerciseEntries)
    }

    // MARK: - Body

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
            .navigationTitle(isEditing ? "Edit Template" : "New Template")
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

    // MARK: - Entry Row

    private func entryRow(entry: Binding<TemplateEntry>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(entry.wrappedValue.exerciseName)
                .font(.subheadline.weight(.medium))

            // Sets / Reps row
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

            // Weight / Rest row
            HStack(spacing: DS.Spacing.md) {
                // Weight input
                HStack(spacing: DS.Spacing.xs) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        "—",
                        value: entry.defaultWeightKg,
                        format: .number.precision(.fractionLength(0...1))
                    )
                    .keyboardType(.decimalPad)
                    .frame(width: 56)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Rest duration picker
                HStack(spacing: DS.Spacing.xs) {
                    Text("Rest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: restDurationBinding(for: entry)) {
                        Text("Default").tag(nil as TimeInterval?)
                        Text("30s").tag(30.0 as TimeInterval?)
                        Text("60s").tag(60.0 as TimeInterval?)
                        Text("90s").tag(90.0 as TimeInterval?)
                        Text("2m").tag(120.0 as TimeInterval?)
                        Text("3m").tag(180.0 as TimeInterval?)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }

    // MARK: - Helpers

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// Creates a binding that maps `TemplateEntry.restDuration` to optional `TimeInterval?`
    /// so it can be used with Picker's tag matching.
    private func restDurationBinding(for entry: Binding<TemplateEntry>) -> Binding<TimeInterval?> {
        Binding<TimeInterval?>(
            get: { entry.wrappedValue.restDuration },
            set: { entry.wrappedValue.restDuration = $0 }
        )
    }

    // MARK: - Save

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

        // Clamp weight values (correction #3: user input range validation)
        let clampedEntries = entries.map { entry in
            var clamped = entry
            if let weight = clamped.defaultWeightKg {
                let trimmedWeight = min(max(weight, 0), 500)
                clamped.defaultWeightKg = trimmedWeight > 0 ? trimmedWeight : nil
            }
            if let rest = clamped.restDuration {
                clamped.restDuration = min(max(rest, 0), 600)
            }
            return clamped
        }

        switch mode {
        case .create:
            let template = WorkoutTemplate(name: trimmed, exerciseEntries: clampedEntries)
            modelContext.insert(template)
        case .edit(let template):
            template.name = String(trimmed.prefix(100))
            template.exerciseEntries = clampedEntries
            template.updatedAt = Date()
        }
        dismiss()
    }
}

// MARK: - Backward Compatibility

/// Alias for existing call sites that use `CreateTemplateView()`.
typealias CreateTemplateView = TemplateFormView
