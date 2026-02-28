import SwiftUI
import SwiftData

struct CreateCustomExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserCategory.sortOrder) private var userCategories: [UserCategory]

    let onCreated: (ExerciseDefinition) -> Void

    @State private var name = ""
    @State private var selectedCategory: ExerciseCategory = .strength
    @State private var selectedUserCategory: UserCategory?
    @State private var selectedInputType: ExerciseInputType = .setsRepsWeight
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var selectedEquipment: Equipment = .bodyweight
    @State private var selectedCardioUnit: CardioSecondaryUnit = .km
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section("Exercise Name") {
                    TextField("e.g. Cable Lateral Raise", text: $name)
                        .autocorrectionDisabled()
                }

                // Category — built-in + user-defined
                Section("Category") {
                    // Built-in categories
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedCategory) { _, newValue in
                        selectedUserCategory = nil
                        switch newValue {
                        case .strength: selectedInputType = .setsRepsWeight
                        case .cardio: selectedInputType = .durationDistance
                        case .hiit: selectedInputType = .roundsBased
                        case .flexibility: selectedInputType = .durationIntensity
                        case .bodyweight: selectedInputType = .setsReps
                        }
                    }

                    // User-defined categories
                    if !userCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Spacing.sm) {
                                ForEach(userCategories) { userCat in
                                    Button {
                                        if selectedUserCategory?.id == userCat.id {
                                            selectedUserCategory = nil
                                        } else {
                                            selectedUserCategory = userCat
                                            selectedInputType = userCat.defaultInputType
                                        }
                                    } label: {
                                        HStack(spacing: DS.Spacing.xs) {
                                            Image(systemName: userCat.iconName)
                                                .font(.caption2)
                                            Text(userCat.name)
                                                .font(.caption.weight(.medium))
                                        }
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.vertical, DS.Spacing.sm)
                                        .background(
                                            selectedUserCategory?.id == userCat.id
                                                ? (Color(hex: userCat.colorHex) ?? DS.Color.activity)
                                                : Color.secondary.opacity(0.12),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(
                                            selectedUserCategory?.id == userCat.id ? .white : .primary
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: DS.Spacing.xs, leading: DS.Spacing.lg, bottom: DS.Spacing.xs, trailing: DS.Spacing.lg))
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

                    if selectedInputType == .durationDistance {
                        Picker("Distance Unit", selection: $selectedCardioUnit) {
                            Text("Kilometers").tag(CardioSecondaryUnit.km)
                            Text("Meters").tag(CardioSecondaryUnit.meters)
                            Text("Floors").tag(CardioSecondaryUnit.floors)
                            Text("Count").tag(CardioSecondaryUnit.count)
                            Text("Time only").tag(CardioSecondaryUnit.timeOnly)
                        }
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
            .scrollContentBackground(.hidden)
            .background { SheetWaveBackground() }
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
            equipment: selectedEquipment,
            customCategoryName: selectedUserCategory?.name,
            cardioSecondaryUnit: selectedInputType == .durationDistance ? selectedCardioUnit : nil
        )
        modelContext.insert(custom)

        let definition = custom.toDefinition()
        dismiss()
        onCreated(definition)
    }
}
