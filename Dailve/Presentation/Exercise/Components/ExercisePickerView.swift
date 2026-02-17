import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    let library: ExerciseLibraryQuerying
    let recentExerciseIDs: [String]
    let onSelect: (ExerciseDefinition) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomExercise.createdAt, order: .reverse) private var customExercises: [CustomExercise]
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedMuscle: MuscleGroup?
    @State private var selectedEquipment: Equipment?
    @State private var showingCreateCustom = false

    private var customDefinitions: [ExerciseDefinition] {
        customExercises.map { $0.toDefinition() }
    }

    private var filteredExercises: [ExerciseDefinition] {
        var libraryResults: [ExerciseDefinition]
        var customResults: [ExerciseDefinition]

        if !searchText.isEmpty {
            libraryResults = library.search(query: searchText)
            let query = searchText.lowercased()
            customResults = customDefinitions.filter {
                $0.localizedName.localizedCaseInsensitiveContains(query)
            }
        } else if let category = selectedCategory {
            libraryResults = library.exercises(forCategory: category)
            customResults = customDefinitions.filter { $0.category == category }
        } else {
            libraryResults = library.allExercises()
            customResults = customDefinitions
        }

        // Apply muscle filter
        if let muscle = selectedMuscle {
            libraryResults = libraryResults.filter {
                $0.primaryMuscles.contains(muscle) || $0.secondaryMuscles.contains(muscle)
            }
            customResults = customResults.filter {
                $0.primaryMuscles.contains(muscle) || $0.secondaryMuscles.contains(muscle)
            }
        }

        // Apply equipment filter
        if let equipment = selectedEquipment {
            libraryResults = libraryResults.filter { $0.equipment == equipment }
            customResults = customResults.filter { $0.equipment == equipment }
        }

        return customResults + libraryResults
    }

    private var recentExercises: [ExerciseDefinition] {
        recentExerciseIDs.compactMap { id in
            library.exercise(byID: id)
                ?? customDefinitions.first { $0.id == id }
        }
    }

    private var hasActiveFilters: Bool {
        selectedCategory != nil || selectedMuscle != nil || selectedEquipment != nil
    }

    var body: some View {
        NavigationStack {
            List {
                // Recent exercises section
                if searchText.isEmpty && !hasActiveFilters && !recentExercises.isEmpty {
                    Section("Recent") {
                        ForEach(recentExercises) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                }

                // Filters
                if searchText.isEmpty {
                    filtersSection
                }

                // Exercise list
                Section {
                    ForEach(filteredExercises) { exercise in
                        exerciseRow(exercise)
                    }
                } header: {
                    if hasActiveFilters {
                        HStack {
                            Text("\(filteredExercises.count) exercises")
                            Spacer()
                            Button("Clear Filters") {
                                withAnimation(DS.Animation.snappy) {
                                    selectedCategory = nil
                                    selectedMuscle = nil
                                    selectedEquipment = nil
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateCustom = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateCustom) {
                CreateCustomExerciseView { definition in
                    onSelect(definition)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Filters

    @ViewBuilder
    private var filtersSection: some View {
        // Category filter
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                categoryChip(nil, label: "All")
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    categoryChip(category, label: category.displayName)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

        // Muscle group filter
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    muscleChip(muscle)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

        // Equipment filter
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "dumbbell")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    equipmentChip(equipment)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // MARK: - Rows

    private func exerciseRow(_ exercise: ExerciseDefinition) -> some View {
        Button {
            onSelect(exercise)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(exercise.localizedName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if exercise.id.hasPrefix("custom-") {
                            Text("Custom")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, 1)
                                .background(DS.Color.activity.opacity(0.15), in: Capsule())
                                .foregroundStyle(DS.Color.activity)
                        }
                    }
                    HStack(spacing: DS.Spacing.xs) {
                        Text(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\u{00B7}")
                            .foregroundStyle(.tertiary)
                        Text(exercise.equipment.displayName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Image(systemName: WorkoutSummary.iconName(for: exercise.name))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Chips

    private func categoryChip(_ category: ExerciseCategory?, label: String) -> some View {
        Button {
            withAnimation(DS.Animation.snappy) {
                selectedCategory = category
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    selectedCategory == category
                        ? DS.Color.activity
                        : Color.secondary.opacity(0.15),
                    in: Capsule()
                )
                .foregroundStyle(
                    selectedCategory == category ? .white : .primary
                )
        }
        .buttonStyle(.plain)
    }

    private func muscleChip(_ muscle: MuscleGroup) -> some View {
        Button {
            withAnimation(DS.Animation.snappy) {
                selectedMuscle = selectedMuscle == muscle ? nil : muscle
            }
        } label: {
            Text(muscle.displayName)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(
                    selectedMuscle == muscle
                        ? DS.Color.activity
                        : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .foregroundStyle(
                    selectedMuscle == muscle ? .white : .primary
                )
        }
        .buttonStyle(.plain)
    }

    private func equipmentChip(_ equipment: Equipment) -> some View {
        Button {
            withAnimation(DS.Animation.snappy) {
                selectedEquipment = selectedEquipment == equipment ? nil : equipment
            }
        } label: {
            Text(equipment.displayName)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(
                    selectedEquipment == equipment
                        ? DS.Color.activity
                        : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .foregroundStyle(
                    selectedEquipment == equipment ? .white : .primary
                )
        }
        .buttonStyle(.plain)
    }
}
