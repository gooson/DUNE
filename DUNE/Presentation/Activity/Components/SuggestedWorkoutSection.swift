import SwiftUI
import SwiftData

/// Suggested workout section with integrated exercise search and template strip.
struct SuggestedWorkoutSection: View {
    let suggestion: WorkoutSuggestion?
    let recommendationContext: WorkoutRecommendationContext
    let availableEquipment: [Equipment]
    let library: ExerciseLibraryQuerying
    let recentExerciseIDs: [String]
    let popularExerciseIDs: [String]
    let onStartExercise: (ExerciseDefinition) -> Void
    let onStartTemplate: (WorkoutTemplate) -> Void
    let onContextChanged: (WorkoutRecommendationContext) -> Void
    let isEquipmentAvailable: (Equipment) -> Bool
    let onSetEquipmentAvailability: (Equipment, Bool) -> Void
    let isExerciseExcluded: (String) -> Bool
    let onSetExerciseExcluded: (Bool, String) -> Void
    let onBrowseAll: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var showingEquipmentSheet = false
    @State private var searchText = ""

    @Query(sort: \CustomExercise.createdAt, order: .reverse) private var customExercises: [CustomExercise]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var customDefinitions: [ExerciseDefinition] {
        customExercises.map { $0.toDefinition() }
    }

    private var filteredExercises: [ExerciseDefinition] {
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
            priorityIDs: popularExerciseIDs + recentExerciseIDs
        )
        return QuickStartSupport.uniqueByCanonical(sorted)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DS.Spacing.sm),
            GridItem(.flexible(), spacing: DS.Spacing.sm),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            searchField

            if isSearching {
                searchResultsSection
            } else {
                recommendationControlsCard

                if let suggestion {
                    if suggestion.isRestDay {
                        restDayContent(suggestion: suggestion)
                    } else {
                        workoutContent(suggestion: suggestion)
                    }
                } else {
                    noSuggestionContent
                }

                if !templates.isEmpty {
                    templateStrip
                }

                Button("All Exercises") {
                    onBrowseAll()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.activity)
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingEquipmentSheet) {
            RecommendationEquipmentSheet(
                context: recommendationContext,
                isEquipmentAvailable: isEquipmentAvailable,
                onSetEquipmentAvailability: onSetEquipmentAvailability
            )
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DS.Color.textSecondary)

            TextField("Search exercises", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("activity-exercise-search")

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
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.75)
                )
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if filteredExercises.isEmpty {
            InlineCard {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.tertiary)
                    Text("No Exercises")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                    Spacer()
                }
            }
        } else {
            searchExerciseList(exercises: filteredExercises)
        }
    }

    private func searchExerciseList(exercises: [ExerciseDefinition]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader("All Exercises")

            ForEach(exercises) { exercise in
                Button {
                    onStartExercise(exercise)
                } label: {
                    exerciseRow(exercise)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Controls

    private var recommendationControlsCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Picker(
                    "Workout Context",
                    selection: Binding(
                        get: { recommendationContext },
                        set: { onContextChanged($0) }
                    )
                ) {
                    Text("Gym")
                        .tag(WorkoutRecommendationContext.gym)
                    Text("Home")
                        .tag(WorkoutRecommendationContext.home)
                }
                .pickerStyle(.segmented)

                Button {
                    showingEquipmentSheet = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "dumbbell.fill")
                            .font(.caption)
                            .foregroundStyle(DS.Color.activity)

                        Text("Equipment")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.Color.textSecondary)

                        Spacer(minLength: DS.Spacing.xs)

                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "%lld selected"),
                                Int64(availableEquipment.count)
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noSuggestionContent: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("No matching workout suggestions")
                    .font(.subheadline.weight(.semibold))

                Text("Update your equipment or remove not-interested exercises.")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    // MARK: - Workout

    private func workoutContent(suggestion: WorkoutSuggestion) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if !suggestion.focusMuscles.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(suggestion.focusMuscles, id: \.self) { muscle in
                            Text(muscle.displayName)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(DS.Color.activity.opacity(0.12), in: Capsule())
                                .foregroundStyle(DS.Color.activity)
                        }
                    }
                }

                LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                    ForEach(suggestion.exercises) { exercise in
                        let excluded = isExerciseExcluded(exercise.id)
                        SuggestedExerciseRow(
                            exercise: exercise,
                            isExcluded: excluded,
                            onStart: { onStartExercise(exercise.definition) },
                            onToggleInterest: {
                                onSetExerciseExcluded(!excluded, exercise.id)
                            },
                            onAlternativeSelected: { alt in onStartExercise(alt) }
                        )
                        .padding(DS.Spacing.sm)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                }
            }
        }
    }

    // MARK: - Rest Day

    private func restDayContent(suggestion: WorkoutSuggestion) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bed.double.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Recovery Day")
                        .font(.subheadline.weight(.semibold))
                }

                Text(suggestion.reasoning)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                if let next = suggestion.nextReadyMuscle {
                    nextReadyLabel(muscle: next.muscle, date: next.readyDate)
                }

                if !suggestion.activeRecoverySuggestions.isEmpty {
                    ActiveRecoveryCard(suggestions: suggestion.activeRecoverySuggestions)
                }
            }
        }
    }

    private func nextReadyLabel(muscle: MuscleGroup, date: Date) -> some View {
        let hours = Swift.max(0, date.timeIntervalSince(Date()) / 3600)
        let timeText: String
        if hours < 1 {
            timeText = String(localized: "soon")
        } else if hours < 24 {
            timeText = String.localizedStringWithFormat(
                String(localized: "in ~%@h"),
                Int(hours).formattedWithSeparator
            )
        } else {
            let days = Int(hours / 24)
            timeText = String.localizedStringWithFormat(
                String(localized: "in ~%@d"),
                days.formattedWithSeparator
            )
        }

        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
            Text(
                String.localizedStringWithFormat(
                    String(localized: "%@ ready %@"),
                    muscle.displayName,
                    timeText
                )
            )
            .font(.caption)
            .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Templates

    private var templateStrip: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader("Templates")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(templates) { template in
                        Button {
                            onStartTemplate(template)
                        } label: {
                            templateCard(template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(DS.Color.textSecondary)
    }

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "list.clipboard.fill")
                        .foregroundStyle(DS.Color.activity)
                    Text(template.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.sandColor)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.Color.activity)
                }

                Text("\(template.exerciseEntries.count.formattedWithSeparator) exercises")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                if !template.exerciseEntries.isEmpty {
                    Text(template.exerciseEntries.map(\.exerciseName).prefix(2).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(width: 220, alignment: .leading)
        }
    }

    private func exerciseRow(_ exercise: ExerciseDefinition) -> some View {
        InlineCard {
            HStack(spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(exercise.localizedName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.sandColor)
                            .lineLimit(1)

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
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    HStack(spacing: DS.Spacing.xs) {
                        Text(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(1)
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

                Spacer(minLength: 0)

                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Color.activity)
            }
        }
    }
}

private struct RecommendationEquipmentSheet: View {
    let context: WorkoutRecommendationContext
    let isEquipmentAvailable: (Equipment) -> Bool
    let onSetEquipmentAvailability: (Equipment, Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch context {
        case .gym:
            return "Gym Equipment"
        case .home:
            return "Home Equipment"
        }
    }

    private var selectableEquipment: [Equipment] {
        Equipment.allCases.filter { $0 != .other }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(selectableEquipment, id: \.self) { equipment in
                        Toggle(
                            isOn: Binding(
                                get: { isEquipmentAvailable(equipment) },
                                set: { isOn in
                                    onSetEquipmentAvailability(equipment, isOn)
                                }
                            )
                        ) {
                            HStack(spacing: DS.Spacing.xs) {
                                equipment.svgIcon(size: 18)
                                    .foregroundStyle(DS.Color.activity)

                                Text(equipment.displayName)
                                    .font(.subheadline)
                            }
                        }
                    }
                } footer: {
                    Text("At least one equipment is always kept to avoid an empty recommendation.")
                }
            }
            .englishNavigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
