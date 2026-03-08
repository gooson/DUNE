import SwiftUI
import SwiftData

enum ExercisePickerMode {
    case full
    case quickStart
}

struct ExercisePickerView: View {
    let library: ExerciseLibraryQuerying
    let recentExerciseIDs: [String]
    let preferredExerciseIDs: [String]
    let popularExerciseIDs: [String]
    let mode: ExercisePickerMode
    let onStartTemplate: ((WorkoutTemplate) -> Void)?
    let onSelect: (ExerciseDefinition) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomExercise.createdAt, order: .reverse) private var customExercises: [CustomExercise]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \UserCategory.sortOrder) private var userCategories: [UserCategory]
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedUserCategoryName: String?
    @State private var selectedMuscle: MuscleGroup?
    @State private var selectedEquipment: Equipment?
    @State private var showingCreateCustom = false
    @State private var detailExercise: ExerciseDefinition?
    @State private var showingAllQuickStartExercises = false

    init(
        library: ExerciseLibraryQuerying,
        recentExerciseIDs: [String],
        preferredExerciseIDs: [String] = [],
        popularExerciseIDs: [String] = [],
        mode: ExercisePickerMode = .full,
        onStartTemplate: ((WorkoutTemplate) -> Void)? = nil,
        onSelect: @escaping (ExerciseDefinition) -> Void
    ) {
        self.library = library
        self.recentExerciseIDs = recentExerciseIDs
        self.preferredExerciseIDs = preferredExerciseIDs
        self.popularExerciseIDs = popularExerciseIDs
        self.mode = mode
        self.onStartTemplate = onStartTemplate
        self.onSelect = onSelect
    }

    private var customDefinitions: [ExerciseDefinition] {
        customExercises.map { $0.toDefinition() }
    }

    private var isQuickStartMode: Bool {
        mode == .quickStart
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var fullModeFilteredExercises: [ExerciseDefinition] {
        var libraryResults: [ExerciseDefinition]
        var customResults: [ExerciseDefinition]

        if !trimmedSearchText.isEmpty {
            libraryResults = QuickStartSupport.mergedSearchResults(for: trimmedSearchText, library: library)
            customResults = customDefinitions.filter {
                QuickStartSupport.matchesSearchQuery(trimmedSearchText, in: $0)
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

    private var quickStartFilteredExercises: [ExerciseDefinition] {
        let definitions: [ExerciseDefinition]
        if trimmedSearchText.isEmpty {
            definitions = customDefinitions + library.allExercises()
        } else {
            let customResults = customDefinitions.filter {
                QuickStartSupport.matchesSearchQuery(trimmedSearchText, in: $0)
            }
            definitions = customResults + QuickStartSupport.mergedSearchResults(
                for: trimmedSearchText,
                library: library
            )
        }

        let sorted = QuickStartSupport.sortQuickStartExercises(
            QuickStartSupport.uniqueByID(definitions),
            priorityIDs: quickStartPriorityIDs
        )
        return QuickStartSupport.uniqueByCanonical(sorted)
    }

    private var filteredExercises: [ExerciseDefinition] {
        isQuickStartMode ? quickStartFilteredExercises : fullModeFilteredExercises
    }

    private var recentExercises: [ExerciseDefinition] {
        quickStartOrdering.recentIDs.compactMap {
            QuickStartSupport.resolveExerciseDefinition(
                by: $0,
                library: library,
                customDefinitions: customDefinitions
            )
        }
    }

    private var preferredExercises: [ExerciseDefinition] {
        quickStartOrdering.preferredIDs.compactMap {
            QuickStartSupport.resolveExerciseDefinition(
                by: $0,
                library: library,
                customDefinitions: customDefinitions
            )
        }
    }

    private var popularExercises: [ExerciseDefinition] {
        quickStartOrdering.popularIDs.compactMap {
            QuickStartSupport.resolveExerciseDefinition(
                by: $0,
                library: library,
                customDefinitions: customDefinitions
            )
        }
    }

    private var quickStartOrdering: QuickStartSectionOrdering {
        QuickStartSectionOrderingService.make(
            recentIDs: recentExerciseIDs,
            preferredIDs: preferredExerciseIDs,
            popularIDs: popularExerciseIDs,
            canonicalize: QuickStartCanonicalService.canonicalExerciseID(for:)
        )
    }

    private var hasActiveFilters: Bool {
        selectedCategory != nil || selectedUserCategoryName != nil || selectedMuscle != nil || selectedEquipment != nil
    }

    private var shouldShowQuickStartHub: Bool {
        isQuickStartMode && !showingAllQuickStartExercises && trimmedSearchText.isEmpty
    }

    private var quickStartPriorityIDs: [String] {
        var seen = Set<String>()
        return quickStartOrdering.priorityIDs.compactMap { id in
            let representativeID = library.representativeExercise(byID: id)?.id ?? id
            guard !representativeID.isEmpty else { return nil }
            return seen.insert(representativeID).inserted ? representativeID : nil
        }
    }

    private var quickStartAllSectionTitle: LocalizedStringKey {
        searchText.isEmpty ? "All Exercises" : "Results"
    }

    var body: some View {
        NavigationStack {
            exerciseList
                .englishNavigationTitle(isQuickStartMode ? "Quick Start" : "Select Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("picker-cancel-button")
                    }

                    if !isQuickStartMode {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showingCreateCustom = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityIdentifier("picker-create-custom-button")
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

    @ViewBuilder
    private var exerciseList: some View {
        List {
            if isQuickStartMode {
                quickStartSearchSection
            }

            if isQuickStartMode, trimmedSearchText.isEmpty, let onStartTemplate, !templates.isEmpty {
                quickStartTemplateSection(onStartTemplate: onStartTemplate)
            }

            if shouldShowQuickStartHub {
                quickStartHubSections
            } else if isQuickStartMode {
                quickStartAllSection
            } else {
                fullModeSections
            }
        }
        .accessibilityIdentifier("picker-root-list")
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .background { SheetWaveBackground() }
        .modifier(FullModeSearchModifier(isQuickStartMode: isQuickStartMode, searchText: $searchText))
    }

    @ViewBuilder
    private var fullModeSections: some View {
        // Recent exercises section
        if trimmedSearchText.isEmpty && !hasActiveFilters && !recentExercises.isEmpty {
            Section {
                ForEach(recentExercises) { exercise in
                    exerciseRow(exercise)
                }
            } header: {
                Text("Recent")
                    .accessibilityIdentifier("picker-section-recent")
            }
        }

        // Filters
        if trimmedSearchText.isEmpty {
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
                    .accessibilityIdentifier("picker-clear-filters")
                }
            }
        }
    }

    @ViewBuilder
    private var quickStartHubSections: some View {
        if !recentExercises.isEmpty {
            Section {
                ForEach(recentExercises) { exercise in
                    exerciseRow(exercise)
                }
            } header: {
                Text("Recent")
                    .accessibilityIdentifier("picker-section-recent")
            }
        }

        if !preferredExercises.isEmpty {
            Section {
                ForEach(preferredExercises) { exercise in
                    exerciseRow(exercise)
                }
            } header: {
                Text("Preferred")
                    .accessibilityIdentifier("picker-section-preferred")
            }
        }

        if !popularExercises.isEmpty {
            Section {
                ForEach(popularExercises) { exercise in
                    exerciseRow(exercise)
                }
            } header: {
                Text("Popular")
                    .accessibilityIdentifier("picker-section-popular")
            }
        }

        Section {
            Button {
                showingAllQuickStartExercises = true
            } label: {
                HStack {
                    Label("All Exercises", systemImage: "plus.circle.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(DS.Color.activity)
            .accessibilityIdentifier("picker-all-exercises-button")
        }
    }

    @ViewBuilder
    private var quickStartSearchSection: some View {
        Section {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Color.textSecondary)

                TextField("Search exercises", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityIdentifier("picker-search-field")

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private func quickStartTemplateSection(
        onStartTemplate: @escaping (WorkoutTemplate) -> Void
    ) -> some View {
        Section {
            ForEach(templates) { template in
                Button {
                    dismissPicker {
                        onStartTemplate(template)
                    }
                } label: {
                    templateRow(template)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(templateRowIdentifier(template))
            }
        } header: {
            Text("Templates")
                .accessibilityIdentifier("picker-section-templates")
        }
    }

    @ViewBuilder
    private var quickStartAllSection: some View {
        Section {
            ForEach(filteredExercises) { exercise in
                exerciseRow(exercise)
            }
        } header: {
            HStack {
                Text(quickStartAllSectionTitle)
                    .accessibilityIdentifier("picker-section-all")
                Spacer()
                if showingAllQuickStartExercises && trimmedSearchText.isEmpty {
                    Button("Hide") {
                        searchText = ""
                        showingAllQuickStartExercises = false
                    }
                    .font(.caption)
                    .accessibilityIdentifier("picker-hide-all-button")
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
                // User-defined categories
                ForEach(userCategories) { userCat in
                    userCategoryChip(userCat)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .accessibilityIdentifier("picker-filter-category-scroll")
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

        // Muscle group filter
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    muscleChip(muscle)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .accessibilityIdentifier("picker-filter-muscle-scroll")
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

        // Equipment filter
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "dumbbell")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    equipmentChip(equipment)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .accessibilityIdentifier("picker-filter-equipment-scroll")
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // MARK: - Rows

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "list.clipboard.fill")
                    .foregroundStyle(DS.Color.activity)
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(theme.sandColor)
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Color.activity)
            }

            HStack(spacing: DS.Spacing.xs) {
                Text("\(template.exerciseEntries.count.formattedWithSeparator) exercises")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                if !template.exerciseEntries.isEmpty {
                    Text("\u{00B7}")
                        .foregroundStyle(.tertiary)
                    Text(template.exerciseEntries.map(\.exerciseName).prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }

    private func exerciseRow(_ exercise: ExerciseDefinition) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                dismissPicker {
                    onSelect(exercise)
                }
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(exercise.localizedName)
                            .font(.body)
                            .foregroundStyle(theme.sandColor)
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
                        Text(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                        Text("\u{00B7}")
                            .foregroundStyle(.tertiary)
                        Label {
                            Text(exercise.equipment.displayName)
                        } icon: {
                            exercise.equipment.svgIcon(size: 12)
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityIdentifier("picker-row-\(exercise.id)")

            Button {
                detailExercise = exercise
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("picker-detail-\(exercise.id)")
        }
    }

    private func dismissPicker(_ action: @escaping @MainActor () -> Void) {
        dismiss()
        Task { @MainActor in
            await Task.yield()
            action()
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
                    isSelected ? .white : theme.sandColor
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(categoryChipIdentifier(category))
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
                isSelected ? .white : theme.sandColor
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(userCategoryChipIdentifier(userCat))
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
                    selectedMuscle == muscle ? .white : theme.sandColor
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(muscleChipIdentifier(muscle))
    }

    private func equipmentChip(_ equipment: Equipment) -> some View {
        Button {
            withAnimation(DS.Animation.snappy) {
                selectedEquipment = selectedEquipment == equipment ? nil : equipment
            }
        } label: {
            HStack(spacing: DS.Spacing.xxs) {
                equipment.svgIcon(size: 14)
                Text(equipment.displayName)
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
                selectedEquipment == equipment ? .white : theme.sandColor
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(equipmentChipIdentifier(equipment))
    }

    private func templateRowIdentifier(_ template: WorkoutTemplate) -> String {
        "picker-template-\(template.id.uuidString.lowercased())"
    }

    private func categoryChipIdentifier(_ category: ExerciseCategory?) -> String {
        "picker-filter-category-\(category?.rawValue ?? "all")"
    }

    private func userCategoryChipIdentifier(_ userCategory: UserCategory) -> String {
        "picker-filter-user-category-\(userCategory.id.uuidString.lowercased())"
    }

    private func muscleChipIdentifier(_ muscle: MuscleGroup) -> String {
        "picker-filter-muscle-\(muscle.rawValue)"
    }

    private func equipmentChipIdentifier(_ equipment: Equipment) -> String {
        "picker-filter-equipment-\(equipment.rawValue)"
    }

}

private struct FullModeSearchModifier: ViewModifier {
    let isQuickStartMode: Bool
    @Binding var searchText: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isQuickStartMode {
            content
        } else {
            content.searchable(text: $searchText, prompt: "Search exercises")
        }
    }
}
