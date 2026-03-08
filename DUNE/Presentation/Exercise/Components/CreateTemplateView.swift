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
                        .accessibilityIdentifier("template-form-name")
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
                    .accessibilityIdentifier("template-form-add-exercise")
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
            .accessibilityIdentifier("template-form-screen")
            .scrollContentBackground(.hidden)
            .background { SheetWaveBackground() }
            .englishNavigationTitle(isEditing ? "Edit Template" : "New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("template-form-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTemplate() }
                        .fontWeight(.semibold)
                        .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty || entries.isEmpty)
                        .accessibilityIdentifier("template-form-save")
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    library: library,
                    recentExerciseIDs: [],
                    mode: .full
                ) { exercise in
                    entries.append(TemplateExerciseResolver.defaultEntry(for: exercise))
                }
            }
        }
    }

    // MARK: - Entry Row

    private func entryRow(entry: Binding<TemplateEntry>) -> some View {
        let profile = TemplateExerciseResolver.profile(
            for: entry.wrappedValue,
            library: library,
            customExercises: customExercises
        )

        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(entry.wrappedValue.exerciseName)
                .font(.subheadline.weight(.medium))

            if profile.showsStrengthDefaultsEditor {
                strengthDefaultsEditor(entry: entry)
            } else {
                sessionDrivenSummary(profile: profile)
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }

    private func strengthDefaultsEditor(entry: Binding<TemplateEntry>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Sets")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
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
                        .foregroundStyle(DS.Color.textSecondary)
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

            HStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
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
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Text("Rest")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
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
    }

    private func sessionDrivenSummary(profile: TemplateExerciseProfile) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(profile.primarySummaryLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            if let secondary = profile.secondarySummaryLabel {
                Text("\u{00B7}")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
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
            validationError = String(localized: "Template name is required")
            return
        }
        guard trimmed.count <= 100 else {
            validationError = String(localized: "Name must be 100 characters or less")
            return
        }
        guard !entries.isEmpty else {
            validationError = String(localized: "Add at least one exercise")
            return
        }

        // Clamp weight values (correction #3: user input range validation)
        let clampedEntries = entries.map { entry in
            var clamped = TemplateExerciseResolver.entryWithResolvedMetadata(
                from: entry,
                library: library,
                customExercises: customExercises
            )
            let profile = TemplateExerciseResolver.profile(
                for: clamped,
                library: library,
                customExercises: customExercises
            )
            if case .cardio = profile {
                clamped.defaultSets = 1
                clamped.defaultWeightKg = nil
                clamped.restDuration = nil
            }
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
