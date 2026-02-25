import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    let library: ExerciseLibraryQuerying
    let recentExerciseIDs: [String]
    let onSelect: (ExerciseDefinition) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomExercise.createdAt, order: .reverse) private var customExercises: [CustomExercise]
    @Query(sort: \UserCategory.sortOrder) private var userCategories: [UserCategory]
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedUserCategoryName: String?
    @State private var selectedMuscle: MuscleGroup?
    @State private var selectedEquipment: Equipment?
    @State private var showingCreateCustom = false
    @State private var detailExercise: ExerciseDefinition?

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
        } else if let userCatName = selectedUserCategoryName {
            // User-defined category filter — only applies to custom exercises
            libraryResults = []
            customResults = customDefinitions.filter { $0.customCategoryName == userCatName }
        } else if let category = selectedCategory {
            libraryResults = library.exercises(forCategory: category)
            customResults = customDefinitions.filter { $0.category == category && $0.customCategoryName == nil }
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
            let allowedEquipment = equipment.compatibleLibraryValues
            libraryResults = libraryResults.filter { allowedEquipment.contains($0.equipment) }
            customResults = customResults.filter { allowedEquipment.contains($0.equipment) }
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
        selectedCategory != nil || selectedUserCategoryName != nil || selectedMuscle != nil || selectedEquipment != nil
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
                                    selectedUserCategoryName = nil
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
            .sheet(item: $detailExercise) { exercise in
                let freshExercise = library.exercise(byID: exercise.id)
                    ?? customDefinitions.first { $0.id == exercise.id }
                    ?? exercise
                ExerciseDetailSheet(exercise: freshExercise) {
                    onSelect(freshExercise)
                    dismiss()
                }
                .presentationDetents([.medium, .large])
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
                // User-defined categories
                ForEach(userCategories) { userCat in
                    userCategoryChip(userCat)
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
                    if exercise.localizedName != exercise.name {
                        Text(exercise.name)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: DS.Spacing.xs) {
                        Text(exercise.primaryMuscles.map(\.localizedDisplayName).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\u{00B7}")
                            .foregroundStyle(.tertiary)
                        Label(exercise.equipment.localizedDisplayName, systemImage: exercise.equipment.iconName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()

                Button {
                    detailExercise = exercise
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Chips

    private func categoryChip(_ category: ExerciseCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category && selectedUserCategoryName == nil
        return Button {
            withAnimation(DS.Animation.snappy) {
                selectedCategory = category
                selectedUserCategoryName = nil
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    isSelected
                        ? DS.Color.activity
                        : Color.secondary.opacity(0.15),
                    in: Capsule()
                )
                .foregroundStyle(
                    isSelected ? .white : .primary
                )
        }
        .buttonStyle(.plain)
    }

    private func userCategoryChip(_ userCat: UserCategory) -> some View {
        let isSelected = selectedUserCategoryName == userCat.name
        return Button {
            withAnimation(DS.Animation.snappy) {
                if isSelected {
                    selectedUserCategoryName = nil
                } else {
                    selectedUserCategoryName = userCat.name
                    selectedCategory = nil
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: userCat.iconName)
                    .font(.system(size: 9))
                Text(userCat.name)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected
                    ? (Color(hex: userCat.colorHex) ?? DS.Color.activity)
                    : Color.secondary.opacity(0.15),
                in: Capsule()
            )
            .foregroundStyle(
                isSelected ? .white : .primary
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
            Text(muscle.localizedDisplayName)
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
            HStack(spacing: DS.Spacing.xxs) {
                Image(equipment.svgAssetName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                Text(equipment.localizedDisplayName)
                    .font(.system(size: 11, weight: .medium))
            }
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
