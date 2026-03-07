import SwiftUI

/// Full exercise list for Quick Start, accessible from the carousel's "All Exercises" card.
/// Groups exercises by category (derived from inputType) when not searching.
struct QuickStartAllExercisesView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var searchText = ""
    @State private var selectedCategory: WatchExerciseCategory?
    @State private var cachedFiltered: [WatchExerciseInfo] = []
    @State private var cachedGrouped: [(category: WatchExerciseCategory, exercises: [WatchExerciseInfo])] = []

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isFilterActive: Bool { selectedCategory != nil }

    var body: some View {
        Group {
            if connectivity.exerciseLibrary.isEmpty {
                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "No Exercises"))
                        .font(DS.Typography.exerciseName)
                    WatchSyncStatusView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
                .accessibilityIdentifier("watch-quickstart-empty")
            } else {
                List {
                    Section {
                        Picker(String(localized: "All Exercises"), selection: $selectedCategory) {
                            Text(String(localized: "All Exercises"))
                                .tag(nil as WatchExerciseCategory?)
                            ForEach(WatchExerciseCategory.ordered, id: \.self) { category in
                                Text(verbatim: category.displayName)
                                    .tag(Optional(category))
                            }
                        }
                        .accessibilityIdentifier("watch-quickstart-category-picker")
                    }

                    if isSearching || isFilterActive {
                        ForEach(cachedFiltered, id: \.id) { exercise in
                            exerciseRow(exercise)
                        }
                    } else {
                        ForEach(cachedGrouped, id: \.category) { group in
                            Section {
                                ForEach(group.exercises, id: \.id) { exercise in
                                    exerciseRow(exercise)
                                }
                            } header: {
                                Text(verbatim: group.category.displayName)
                            }
                        }
                    }
                }
                .accessibilityIdentifier("watch-quickstart-list")
                .scrollContentBackground(.hidden)
            }
        }
        .background { WatchWaveBackground() }
        .navigationTitle(String(localized: "All Exercises"))
        .searchable(text: $searchText, prompt: String(localized: "Search"))
        .onAppear {
            rebuildLists()
            if connectivity.exerciseLibrary.isEmpty {
                connectivity.requestExerciseLibrarySync()
            }
        }
        .onChange(of: searchText) { _, _ in rebuildLists() }
        .onChange(of: selectedCategory) { _, _ in rebuildLists() }
        .onChange(of: connectivity.exerciseLibrary.count) { _, _ in rebuildLists() }
    }

    private func exerciseRow(_ exercise: WatchExerciseInfo) -> some View {
        let subtitle = exerciseSubtitle(for: exercise)
        return NavigationLink(value: WatchRoute.workoutPreview(snapshotFromExercise(exercise))) {
            ExerciseTileView(exercise: exercise, subtitle: subtitle)
        }
        .accessibilityIdentifier("watch-quickstart-exercise-\(exercise.id)")
    }

    private func rebuildLists() {
        let unique = uniqueByCanonical(RecentExerciseTracker.sorted(connectivity.exerciseLibrary))

        if isSearching || isFilterActive {
            cachedFiltered = filterWatchExercises(
                exercises: unique,
                query: searchText,
                category: selectedCategory
            )
            cachedGrouped = []
        } else {
            cachedFiltered = []
            cachedGrouped = groupedWatchExercisesByCategory(unique)
        }
    }
}
