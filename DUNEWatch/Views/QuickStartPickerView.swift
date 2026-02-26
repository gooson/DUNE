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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: WatchExerciseInfo) -> some View {
        NavigationLink(value: WatchRoute.workoutPreview(snapshotFromExercise(exercise))) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text("\(exercise.defaultSets.formattedWithSeparator) sets · \((exercise.defaultReps ?? 10).formattedWithSeparator) reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.right.inward")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No Exercises")
                .font(.headline)
            Text("Open the DUNE app\non your iPhone to sync")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Compute

    private func rebuildSections() {
        let library = connectivity.exerciseLibrary

        cachedPopular = RecentExerciseTracker.personalizedPopular(from: library, limit: 10)
        cachedRecent = library
            .filter { RecentExerciseTracker.lastUsed(exerciseID: $0.id) != nil }
            .sorted {
                let a = RecentExerciseTracker.lastUsed(exerciseID: $0.id) ?? .distantPast
                let b = RecentExerciseTracker.lastUsed(exerciseID: $1.id) ?? .distantPast
                return a > b
            }
    }

    // MARK: - Helpers

    private func snapshotFromExercise(_ exercise: WatchExerciseInfo) -> WorkoutSessionTemplate {
        let entry = TemplateEntry(
            exerciseDefinitionID: exercise.id,
            exerciseName: exercise.name,
            defaultSets: exercise.defaultSets,
            defaultReps: exercise.defaultReps ?? 10,
            defaultWeightKg: exercise.defaultWeightKg
        )
        return WorkoutSessionTemplate(
            name: exercise.name,
            entries: [entry]
        )
    }
}

/// Full exercise list for Quick Start, accessible from the hub's "+" entry.
struct QuickStartAllExercisesView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var searchText = ""
    @State private var cachedFiltered: [WatchExerciseInfo] = []

    private var filteredExercises: [WatchExerciseInfo] { cachedFiltered }

    var body: some View {
        Group {
            if connectivity.exerciseLibrary.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text("No Exercises")
                        .font(.headline)
                }
                .padding()
            } else {
                List {
                    Section("Exercises") {
                        ForEach(filteredExercises, id: \.id) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                }
            }
        }
        .navigationTitle("All Exercises")
        .searchable(text: $searchText, prompt: "Search")
        .onAppear { rebuildFilteredList() }
        .onChange(of: searchText) { _, _ in rebuildFilteredList() }
        .onChange(of: connectivity.exerciseLibrary.map(\.id)) { _, _ in rebuildFilteredList() }
    }

    private func exerciseRow(_ exercise: WatchExerciseInfo) -> some View {
        NavigationLink(value: WatchRoute.workoutPreview(snapshotFromExercise(exercise))) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text("\(exercise.defaultSets.formattedWithSeparator) sets · \((exercise.defaultReps ?? 10).formattedWithSeparator) reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rebuildFilteredList() {
        let library = connectivity.exerciseLibrary
        let base = searchText.isEmpty ? library : library.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        cachedFiltered = RecentExerciseTracker.sorted(base)
    }

    private func snapshotFromExercise(_ exercise: WatchExerciseInfo) -> WorkoutSessionTemplate {
        let entry = TemplateEntry(
            exerciseDefinitionID: exercise.id,
            exerciseName: exercise.name,
            defaultSets: exercise.defaultSets,
            defaultReps: exercise.defaultReps ?? 10,
            defaultWeightKg: exercise.defaultWeightKg
        )
        return WorkoutSessionTemplate(
            name: exercise.name,
            entries: [entry]
        )
    }
}
