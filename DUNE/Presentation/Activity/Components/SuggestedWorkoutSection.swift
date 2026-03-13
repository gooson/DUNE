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
    let onStartRecommendation: (WorkoutTemplateRecommendation) -> Void
    let onSaveRecommendationAsTemplate: ((WorkoutTemplateRecommendation) -> Void)?
    let onStartTemplate: (WorkoutTemplate) -> Void
    let onOpenAIWorkoutBuilder: () -> Void
    let onContextChanged: (WorkoutRecommendationContext) -> Void
    let isEquipmentAvailable: (Equipment) -> Bool
    let onSetEquipmentAvailability: (Equipment, Bool) -> Void
    let isExerciseExcluded: (String) -> Bool
    let onSetExerciseExcluded: (Bool, String) -> Void
    let templateRecommendations: [WorkoutTemplateRecommendation]
    let onBrowseAll: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var showingEquipmentSheet = false
    @State private var searchText = ""
    @State private var cachedFilteredExercises: [ExerciseDefinition] = []
    @State private var detailExercise: ExerciseDefinition?

    @Query(sort: \CustomExercise.createdAt, order: .reverse) private var customExercises: [CustomExercise]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]

    private static let columns: [GridItem] = [
        GridItem(.flexible(), spacing: DS.Spacing.sm),
        GridItem(.flexible(), spacing: DS.Spacing.sm),
    ]

    private static let searchBorderColor = Color.secondary.opacity(0.15)

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            searchField

            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

                if !templateRecommendations.isEmpty {
                    recommendationStrip
                }

                if !templates.isEmpty {
                    templateStrip
                }

                aiWorkoutBuilderEntry

                Button("All Exercises", action: onBrowseAll)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.activity)
                    .buttonStyle(.plain)
            }
        }
        .onChange(of: searchText) { _, _ in rebuildFilteredExercises() }
        .onChange(of: customExercises.count) { _, _ in rebuildFilteredExercises() }
        .sheet(isPresented: $showingEquipmentSheet) {
            RecommendationEquipmentSheet(
                context: recommendationContext,
                isEquipmentAvailable: isEquipmentAvailable,
                onSetEquipmentAvailability: onSetEquipmentAvailability
            )
        }
        .sheet(item: $detailExercise) { exercise in
            let freshExercise = resolvedExercise(for: exercise)
            ExerciseDetailSheet(exercise: freshExercise) {
                onStartExercise(freshExercise)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func rebuildFilteredExercises() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cachedFilteredExercises = []
            return
        }
        let customDefs = customExercises.map { $0.toDefinition() }
        let customResults = customDefs.filter {
            QuickStartSupport.matchesSearchQuery(trimmed, in: $0)
        }
        let definitions = customResults + QuickStartSupport.mergedSearchResults(
            for: trimmed,
            library: library
        )
        let sorted = QuickStartSupport.sortQuickStartExercises(
            QuickStartSupport.uniqueByID(definitions),
            priorityIDs: popularExerciseIDs + recentExerciseIDs
        )
        cachedFilteredExercises = QuickStartSupport.uniqueByCanonical(sorted)
    }

    private func resolvedExercise(for exercise: ExerciseDefinition) -> ExerciseDefinition {
        library.exercise(byID: exercise.id)
            ?? customExercises.first(where: { "custom-\($0.id.uuidString)" == exercise.id })?.toDefinition()
            ?? exercise
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
                        .strokeBorder(Self.searchBorderColor, lineWidth: 0.75)
                )
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if cachedFilteredExercises.isEmpty {
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
            searchExerciseList(exercises: cachedFilteredExercises)
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

                LazyVGrid(columns: Self.columns, spacing: DS.Spacing.sm) {
                    ForEach(suggestion.exercises) { exercise in
                        let excluded = isExerciseExcluded(exercise.id)
                        SuggestedExerciseRow(
                            exercise: exercise,
                            isExcluded: excluded,
                            onShowDetails: { detailExercise = exercise.definition },
                            onStart: { onStartExercise(exercise.definition) },
                            onToggleInterest: {
                                onSetExerciseExcluded(!excluded, exercise.id)
                            },
                            onShowAlternativeDetails: { alt in detailExercise = alt }
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

    // MARK: - Recommendations

    private var recommendationStrip: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader("Suggested Routines")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(templateRecommendations) { recommendation in
                        Button {
                            onStartRecommendation(recommendation)
                        } label: {
                            recommendationCard(recommendation)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) {
                            if let onSave = onSaveRecommendationAsTemplate {
                                Button {
                                    onSave(recommendation)
                                } label: {
                                    Image(systemName: "bookmark")
                                        .font(.caption)
                                        .foregroundStyle(DS.Color.activity)
                                        .padding(DS.Spacing.xs)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Save as Template")
                                .accessibilityIdentifier("activity-recommendation-save-template")
                            }
                        }
                        .accessibilityIdentifier("activity-recommended-routine-card")
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func recommendationCard(_ recommendation: WorkoutTemplateRecommendation) -> some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DS.Color.activity)
                    Text(recommendation.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.sandColor)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                HStack(spacing: DS.Spacing.sm) {
                    Label(
                        String.localizedStringWithFormat(
                            String(localized: "%lldx"),
                            Int64(recommendation.frequency)
                        ),
                        systemImage: "repeat"
                    )
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                    Label(
                        String.localizedStringWithFormat(
                            String(localized: "~%lldmin"),
                            Int64(recommendation.averageDurationMinutes)
                        ),
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                }

                Text(recommendation.sequenceLabels.joined(separator: " → "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 220, alignment: .leading)
        }
    }

    // MARK: - Templates

    private var aiWorkoutBuilderEntry: some View {
        Button(action: onOpenAIWorkoutBuilder) {
            InlineCard {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.Color.activity)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("AI Workout Builder")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text("Describe your ideal workout in natural language and get a ready-to-use template instantly.")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("activity-ai-workout-builder")
    }

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
