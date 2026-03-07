import SwiftUI
import SwiftData

struct ActivityQuickStartSection: View {
    let library: ExerciseLibraryQuerying
    let recentExerciseIDs: [String]
    let popularExerciseIDs: [String]
    let onStartExercise: (ExerciseDefinition) -> Void
    let onStartTemplate: (WorkoutTemplate) -> Void
    let onBrowseAll: () -> Void

    @Environment(\.appTheme) private var theme
    @Query(sort: \CustomExercise.createdAt, order: .reverse) private var customExercises: [CustomExercise]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @State private var searchText = ""

    private enum Limits {
        static let popular = 4
        static let recent = 4
    }

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

    private var popularExercises: [ExerciseDefinition] {
        QuickStartSupport.uniqueByCanonical(
            popularExerciseIDs.compactMap {
                QuickStartSupport.resolveExerciseDefinition(
                    by: $0,
                    library: library,
                    customDefinitions: customDefinitions
                )
            }
        )
    }

    private var recentExercises: [ExerciseDefinition] {
        QuickStartSupport.uniqueByCanonical(
            recentExerciseIDs.compactMap {
                QuickStartSupport.resolveExerciseDefinition(
                    by: $0,
                    library: library,
                    customDefinitions: customDefinitions
                )
            }
        )
    }

    private var quickStartRecentExercises: [ExerciseDefinition] {
        let popularCanonical = Set(popularExercises.map(QuickStartSupport.canonicalKey(for:)))
        return recentExercises.filter { exercise in
            !popularCanonical.contains(QuickStartSupport.canonicalKey(for: exercise))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            searchField

            if trimmedSearchText.isEmpty, !templates.isEmpty {
                templateStrip
            }

            if trimmedSearchText.isEmpty {
                quickStartSections
            } else {
                searchResultsSection
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DS.Color.textSecondary)

            TextField("Search exercises", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("activity-quickstart-search")

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

    private var quickStartSections: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if !popularExercises.isEmpty {
                exerciseSection(
                    title: "Popular",
                    exercises: Array(popularExercises.prefix(Limits.popular))
                )
            }

            if !quickStartRecentExercises.isEmpty {
                exerciseSection(
                    title: "Recent",
                    exercises: Array(quickStartRecentExercises.prefix(Limits.recent))
                )
            }

            Button("All Exercises") {
                onBrowseAll()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(DS.Color.activity)
            .buttonStyle(.plain)
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
            exerciseSection(title: "All Exercises", exercises: filteredExercises)
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(DS.Color.textSecondary)
    }

    private func exerciseSection(
        title: LocalizedStringKey,
        exercises: [ExerciseDefinition]
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(title)

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
