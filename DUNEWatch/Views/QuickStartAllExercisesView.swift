import SwiftUI

// MARK: - Category Label

/// Maps ExerciseInputType rawValue to user-facing category label.
/// Returns "Other" for unrecognized types to avoid silent miscategorisation (#93).
private func categoryLabel(for inputType: String) -> String {
    switch inputType {
    case "setsRepsWeight": return "Strength"
    case "setsReps": return "Bodyweight"
    case "durationDistance": return "Cardio"
    case "durationIntensity": return "Flexibility"
    case "roundsBased": return "HIIT"
    default:
        assertionFailure("Unknown inputType: \(inputType)")
        return "Other"
    }
}

/// Full exercise list for Quick Start, accessible from the carousel's "All Exercises" card.
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
                List {
                    ForEach(cachedFiltered, id: \.id) { exercise in
                        exerciseRow(exercise)
                    }
                }
                .scrollContentBackground(.hidden)
            } else {
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
        .onChange(of: connectivity.exerciseLibrary.count) { _, _ in rebuildLists() }
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
            cachedGrouped = []
        } else {
            cachedFiltered = []
            let unique = uniqueByCanonical(RecentExerciseTracker.sorted(library))
            let grouped = Dictionary(grouping: unique) { categoryLabel(for: $0.inputType) }

            let order = ["Strength", "Bodyweight", "Cardio", "HIIT", "Flexibility", "Other"]
            cachedGrouped = order.compactMap { name in
                guard let exercises = grouped[name], !exercises.isEmpty else { return nil }
                return (category: name, exercises: exercises)
            }
        }
    }
}
