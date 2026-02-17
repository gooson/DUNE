import SwiftUI
import SwiftData

struct CreateCustomExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onCreated: (ExerciseDefinition) -> Void

    @State private var name = ""
    @State private var selectedCategory: ExerciseCategory = .strength
    @State private var selectedInputType: ExerciseInputType = .setsRepsWeight
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var selectedEquipment: Equipment = .bodyweight
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section("Exercise Name") {
                    TextField("e.g. Cable Lateral Raise", text: $name)
                        .autocorrectionDisabled()
                }

                // Category
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedCategory) { _, newValue in
                        // Auto-select appropriate input type
                        switch newValue {
                        case .strength: selectedInputType = .setsRepsWeight
                        case .cardio: selectedInputType = .durationDistance
                        case .hiit: selectedInputType = .roundsBased
                        case .flexibility: selectedInputType = .durationIntensity
                        case .bodyweight: selectedInputType = .setsReps
                        }
                    }
                }

                // Input type
                Section("Input Type") {
                    Picker("Input Type", selection: $selectedInputType) {
                        Text("Sets × Reps × Weight").tag(ExerciseInputType.setsRepsWeight)
                        Text("Sets × Reps").tag(ExerciseInputType.setsReps)
                        Text("Duration + Distance").tag(ExerciseInputType.durationDistance)
                        Text("Duration + Intensity").tag(ExerciseInputType.durationIntensity)
                        Text("Rounds Based").tag(ExerciseInputType.roundsBased)
                    }
                }

                // Muscles
                Section("Primary Muscles") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: DS.Spacing.sm) {
                        ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                            muscleChip(muscle)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }

                // Equipment
                Section("Equipment") {
                    Picker("Equipment", selection: $selectedEquipment) {
                        ForEach(Equipment.allCases, id: \.self) { equip in
                            Text(equip.displayName).tag(equip)
                        }
                    }
                }

                // Validation error
                if let error = validationError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createExercise() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func muscleChip(_ muscle: MuscleGroup) -> some View {
        Button {
            if selectedMuscles.contains(muscle) {
                selectedMuscles.remove(muscle)
            } else {
                selectedMuscles.insert(muscle)
            }
        } label: {
            Text(muscle.displayName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    selectedMuscles.contains(muscle)
                        ? DS.Color.activity
                        : Color.secondary.opacity(0.15),
                    in: Capsule()
                )
                .foregroundStyle(
                    selectedMuscles.contains(muscle) ? .white : .primary
                )
        }
        .buttonStyle(.plain)
    }

    private func createExercise() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            validationError = "Exercise name is required"
            return
        }
        guard trimmed.count <= 100 else {
            validationError = "Name must be 100 characters or less"
            return
        }
        guard !selectedMuscles.isEmpty else {
            validationError = "Select at least one primary muscle"
            return
        }

        let custom = CustomExercise(
            name: trimmed,
            category: selectedCategory,
            inputType: selectedInputType,
            primaryMuscles: Array(selectedMuscles),
            equipment: selectedEquipment
        )
        modelContext.insert(custom)

        let definition = custom.toDefinition()
        dismiss()
        onCreated(definition)
    }
}
