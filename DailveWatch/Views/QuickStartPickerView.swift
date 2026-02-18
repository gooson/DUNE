import SwiftUI

/// Watch exercise picker for Quick Start — starts a single-exercise workout without a template.
/// Uses `WatchConnectivityManager.exerciseLibrary` synced from iPhone.
struct QuickStartPickerView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var searchText = ""
    @State private var cachedFiltered: [WatchExerciseInfo] = []
    @State private var cachedRecent: [WatchExerciseInfo] = []

    private var filteredExercises: [WatchExerciseInfo] { cachedFiltered }
    private var recentExercises: [WatchExerciseInfo] { cachedRecent }

    var body: some View {
        Group {
            if connectivity.exerciseLibrary.isEmpty {
                emptyState
            } else {
                exerciseList
            }
        }
        .navigationTitle("Quick Start")
        .onAppear { rebuildFilteredLists() }
        .onChange(of: searchText) { _, _ in rebuildFilteredLists() }
        .onChange(of: connectivity.exerciseLibrary.count) { _, _ in rebuildFilteredLists() }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        List {
            // Recent section (only when not searching and has history)
            if !recentExercises.isEmpty {
                Section("Recent") {
                    ForEach(recentExercises, id: \.id) { exercise in
                        exerciseRow(exercise)
                    }
                }
            }

            // All exercises
            Section(recentExercises.isEmpty ? "Exercises" : "All") {
                ForEach(filteredExercises, id: \.id) { exercise in
                    exerciseRow(exercise)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: WatchExerciseInfo) -> some View {
        NavigationLink(value: WatchRoute.workoutPreview(
            snapshotFromExercise(exercise)
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text("\(exercise.defaultSets) sets · \(exercise.defaultReps ?? 10) reps")
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
            Text("Open the Dailve app\non your iPhone to sync")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Filter Computation

    private func rebuildFilteredLists() {
        let library = connectivity.exerciseLibrary
        let base = searchText.isEmpty ? library : library.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        cachedFiltered = RecentExerciseTracker.sorted(base)

        if searchText.isEmpty {
            cachedRecent = library.filter {
                RecentExerciseTracker.lastUsed(exerciseID: $0.id) != nil
            }.sorted {
                let a = RecentExerciseTracker.lastUsed(exerciseID: $0.id) ?? .distantPast
                let b = RecentExerciseTracker.lastUsed(exerciseID: $1.id) ?? .distantPast
                return a > b
            }
        } else {
            cachedRecent = []
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
