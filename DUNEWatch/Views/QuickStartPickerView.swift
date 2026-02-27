import SwiftUI

/// Watch Quick Start hub.
/// Default IA: Popular + Recent. Full list is accessible via "+" entry.
struct QuickStartPickerView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var cachedPopular: [WatchExerciseInfo] = []
    @State private var cachedRecent: [WatchExerciseInfo] = []

    private var popularExercises: [WatchExerciseInfo] { cachedPopular }
    private var recentExercises: [WatchExerciseInfo] { cachedRecent }

    var body: some View {
        Group {
            if connectivity.exerciseLibrary.isEmpty {
                emptyState
            } else {
                quickStartHub
            }
        }
        .background { WatchWaveBackground() }
        .navigationTitle("Quick Start")
        .onAppear { rebuildSections() }
        .onChange(of: connectivity.exerciseLibrary.map(\.id)) { _, _ in rebuildSections() }
    }

    // MARK: - Hub

    private var quickStartHub: some View {
        List {
            if !popularExercises.isEmpty {
                Section("Popular") {
                    ForEach(popularExercises, id: \.id) { exercise in
                        exerciseRow(exercise)
                    }
                }
            }

            if !recentExercises.isEmpty {
                Section("Recent") {
                    ForEach(recentExercises, id: \.id) { exercise in
                        exerciseRow(exercise)
                    }
                }
            }

            Section {
                NavigationLink(value: WatchRoute.quickStartAll) {
                    Label("All Exercises", systemImage: "plus.circle.fill")
                        .font(DS.Typography.tileSubtitle)
                        .foregroundStyle(DS.Color.positive)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func exerciseRow(_ exercise: WatchExerciseInfo) -> some View {
        let defaults = resolvedDefaults(for: exercise)
        let subtitle = exerciseSubtitle(sets: exercise.defaultSets, reps: defaults.reps, weight: defaults.weight)
        return NavigationLink(value: WatchRoute.workoutPreview(snapshotFromExercise(exercise))) {
            ExerciseTileView(exercise: exercise, subtitle: subtitle)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "iphone.and.arrow.right.inward")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No Exercises")
                .font(DS.Typography.exerciseName)
            Text("Open the DUNE app\non your iPhone to sync")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Compute

    private func rebuildSections() {
        let library = connectivity.exerciseLibrary
        let lastUsed = RecentExerciseTracker.lastUsedTimestamps()

        cachedPopular = Array(
            uniqueByCanonical(
                RecentExerciseTracker.personalizedPopular(from: library, limit: library.count)
            )
            .prefix(10)
        )

        let popularCanonical = Set(
            cachedPopular.map { RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id) }
        )

        cachedRecent = uniqueByCanonical(
            library
            .filter { lastUsed[$0.id] != nil }
            .sorted {
                let a = lastUsed[$0.id] ?? Date.distantPast.timeIntervalSince1970
                let b = lastUsed[$1.id] ?? Date.distantPast.timeIntervalSince1970
                return a > b
            }
        ).filter { exercise in
            !popularCanonical.contains(RecentExerciseTracker.canonicalExerciseID(exerciseID: exercise.id))
        }
    }

    // MARK: - Helpers

    private func uniqueByCanonical(_ exercises: [WatchExerciseInfo]) -> [WatchExerciseInfo] {
        var seen = Set<String>()
        return exercises.filter { exercise in
            let canonical = RecentExerciseTracker.canonicalExerciseID(exerciseID: exercise.id)
            return seen.insert(canonical).inserted
        }
    }

    private func resolvedDefaults(for exercise: WatchExerciseInfo) -> (weight: Double?, reps: Int) {
        let latest = RecentExerciseTracker.latestSet(exerciseID: exercise.id)
        let reps = latest?.reps ?? exercise.defaultReps ?? 10
        let weight = latest?.weight ?? exercise.defaultWeightKg
        return (weight: weight, reps: reps)
    }

    private func snapshotFromExercise(_ exercise: WatchExerciseInfo) -> WorkoutSessionTemplate {
        let defaults = resolvedDefaults(for: exercise)
        let entry = TemplateEntry(
            exerciseDefinitionID: exercise.id,
            exerciseName: exercise.name,
            defaultSets: exercise.defaultSets,
            defaultReps: defaults.reps,
            defaultWeightKg: defaults.weight,
            equipment: exercise.equipment
        )
        return WorkoutSessionTemplate(
            name: exercise.name,
            entries: [entry]
        )
    }

    /// Builds subtitle: "3 sets · 10 reps" or "3 sets · 10 reps · 80kg"
    private func exerciseSubtitle(sets: Int, reps: Int, weight: Double?) -> String {
        var parts = "\(sets) sets · \(reps) reps"
        if let w = weight, w > 0 {
            parts += " · \(String(format: "%.1f", w))kg"
        }
        return parts
    }
}

/// Full exercise list for Quick Start, accessible from the hub's "+" entry.
/// Groups exercises by category (derived from inputType) when not searching.
struct QuickStartAllExercisesView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var searchText = ""
    @State private var cachedFiltered: [WatchExerciseInfo] = []
    @State private var cachedGrouped: [(category: String, exercises: [WatchExerciseInfo])] = []

    private var isSearching: Bool { !searchText.isEmpty }

    var body: some View {
        Group {
            if connectivity.exerciseLibrary.isEmpty {
                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text("No Exercises")
                        .font(DS.Typography.exerciseName)
                }
                .padding()
            } else if isSearching {
                // Flat filtered list during search
                List {
                    ForEach(cachedFiltered, id: \.id) { exercise in
                        exerciseRow(exercise)
                    }
                }
                .scrollContentBackground(.hidden)
            } else {
                // Category-grouped list
                List {
                    ForEach(cachedGrouped, id: \.category) { group in
                        Section(group.category) {
                            ForEach(group.exercises, id: \.id) { exercise in
                                exerciseRow(exercise)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background { WatchWaveBackground() }
        .navigationTitle("All Exercises")
        .searchable(text: $searchText, prompt: "Search")
        .onAppear { rebuildLists() }
        .onChange(of: searchText) { _, _ in rebuildLists() }
        .onChange(of: connectivity.exerciseLibrary.map(\.id)) { _, _ in rebuildLists() }
    }

    private func exerciseRow(_ exercise: WatchExerciseInfo) -> some View {
        let defaults = resolvedDefaults(for: exercise)
        let subtitle = exerciseSubtitle(sets: exercise.defaultSets, reps: defaults.reps, weight: defaults.weight)
        return NavigationLink(value: WatchRoute.workoutPreview(snapshotFromExercise(exercise))) {
            ExerciseTileView(exercise: exercise, subtitle: subtitle)
        }
    }

    private func rebuildLists() {
        let library = connectivity.exerciseLibrary

        if isSearching {
            let filtered = library.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
            cachedFiltered = uniqueByCanonical(RecentExerciseTracker.sorted(filtered))
        } else {
            // Group by category (derived from inputType)
            let unique = uniqueByCanonical(RecentExerciseTracker.sorted(library))
            let grouped = Dictionary(grouping: unique) { categoryLabel(for: $0.inputType) }

            // Stable ordering: Strength → Bodyweight → Cardio → HIIT → Flexibility
            let order = ["Strength", "Bodyweight", "Cardio", "HIIT", "Flexibility"]
            cachedGrouped = order.compactMap { name in
                guard let exercises = grouped[name], !exercises.isEmpty else { return nil }
                return (category: name, exercises: exercises)
            }
        }
    }

    private func snapshotFromExercise(_ exercise: WatchExerciseInfo) -> WorkoutSessionTemplate {
        let defaults = resolvedDefaults(for: exercise)
        let entry = TemplateEntry(
            exerciseDefinitionID: exercise.id,
            exerciseName: exercise.name,
            defaultSets: exercise.defaultSets,
            defaultReps: defaults.reps,
            defaultWeightKg: defaults.weight,
            equipment: exercise.equipment
        )
        return WorkoutSessionTemplate(
            name: exercise.name,
            entries: [entry]
        )
    }

    private func uniqueByCanonical(_ exercises: [WatchExerciseInfo]) -> [WatchExerciseInfo] {
        var seen = Set<String>()
        return exercises.filter { exercise in
            let canonical = RecentExerciseTracker.canonicalExerciseID(exerciseID: exercise.id)
            return seen.insert(canonical).inserted
        }
    }

    private func resolvedDefaults(for exercise: WatchExerciseInfo) -> (weight: Double?, reps: Int) {
        let latest = RecentExerciseTracker.latestSet(exerciseID: exercise.id)
        let reps = latest?.reps ?? exercise.defaultReps ?? 10
        let weight = latest?.weight ?? exercise.defaultWeightKg
        return (weight: weight, reps: reps)
    }

    /// Builds subtitle: "3 sets · 10 reps" or "3 sets · 10 reps · 80kg"
    private func exerciseSubtitle(sets: Int, reps: Int, weight: Double?) -> String {
        var parts = "\(sets) sets · \(reps) reps"
        if let w = weight, w > 0 {
            parts += " · \(String(format: "%.1f", w))kg"
        }
        return parts
    }

    /// Maps ExerciseInputType rawValue to user-facing category label.
    private func categoryLabel(for inputType: String) -> String {
        switch inputType {
        case "setsRepsWeight": return "Strength"
        case "setsReps": return "Bodyweight"
        case "durationDistance": return "Cardio"
        case "durationIntensity": return "Flexibility"
        case "roundsBased": return "HIIT"
        default: return "Strength"
        }
    }
}
