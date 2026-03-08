import SwiftUI

/// Full exercise list for Quick Start, accessible from the carousel's "All Exercises" card.
/// Shows recent/preferred/popular sections first, then the remaining exercises by category.
struct QuickStartAllExercisesView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var searchText = ""
    @State private var selectedCategory: WatchExerciseCategory?
    @State private var cachedFiltered: [WatchExerciseInfo] = []
    @State private var cachedRecent: [WatchExerciseInfo] = []
    @State private var cachedPreferred: [WatchExerciseInfo] = []
    @State private var cachedPopular: [WatchExerciseInfo] = []
    @State private var cachedGrouped: [(category: WatchExerciseCategory, exercises: [WatchExerciseInfo])] = []

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isFilterActive: Bool { selectedCategory != nil }
    private var exerciseLibrarySnapshot: [String] {
        connectivity.exerciseLibrary.map { exercise in
            let weight = exercise.defaultWeightKg?.description ?? "nil"
            let reps = exercise.defaultReps.map(String.init) ?? "nil"
            let equipment = exercise.equipment ?? "nil"
            return "\(exercise.id)-\(exercise.inputType)-\(exercise.defaultSets)-\(reps)-\(weight)-\(equipment)-\(exercise.isPreferred)"
        }
    }

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
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.quickStartEmpty)
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
                        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.quickStartCategoryPicker)
                    }

                    if isSearching || isFilterActive {
                        ForEach(cachedFiltered, id: \.id) { exercise in
                            exerciseRow(exercise)
                        }
                    } else {
                        if !cachedRecent.isEmpty {
                            Section {
                                ForEach(cachedRecent, id: \.id) { exercise in
                                    exerciseRow(exercise)
                                }
                            } header: {
                                Text("Recent")
                                    .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.quickStartSectionRecent)
                            }
                        }

                        if !cachedPreferred.isEmpty {
                            Section {
                                ForEach(cachedPreferred, id: \.id) { exercise in
                                    exerciseRow(exercise)
                                }
                            } header: {
                                Text("Preferred")
                                    .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.quickStartSectionPreferred)
                            }
                        }

                        if !cachedPopular.isEmpty {
                            Section {
                                ForEach(cachedPopular, id: \.id) { exercise in
                                    exerciseRow(exercise)
                                }
                            } header: {
                                Text("Popular")
                                    .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.quickStartSectionPopular)
                            }
                        }

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
                .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.quickStartList)
                .scrollContentBackground(.hidden)
            }
        }
        .background { WatchWaveBackground() }
        .navigationTitle(String(localized: "All Exercises"))
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.quickStartScreen)
        .searchable(text: $searchText, prompt: String(localized: "Search"))
        .onAppear {
            rebuildLists()
            if connectivity.exerciseLibrary.isEmpty {
                connectivity.requestExerciseLibrarySync()
            }
        }
        .onChange(of: searchText) { _, _ in rebuildLists() }
        .onChange(of: selectedCategory) { _, _ in rebuildLists() }
        .onChange(of: exerciseLibrarySnapshot) { _, _ in rebuildLists() }
    }

    private func exerciseRow(_ exercise: WatchExerciseInfo) -> some View {
        let subtitle = exerciseSubtitle(for: exercise)
        return NavigationLink(value: WatchRoute.workoutPreview(snapshotFromExercise(exercise))) {
            ExerciseTileView(exercise: exercise, subtitle: subtitle)
        }
        .accessibilityIdentifier(WatchWorkoutSurfaceAccessibility.quickStartExercise(exercise.id))
    }

    private func rebuildLists() {
        let unique = uniqueByCanonical(connectivity.exerciseLibrary)
        let lastUsed = RecentExerciseTracker.lastUsedTimestamps()
        let recent = recentWatchExercises(
            from: unique,
            limit: 20,
            lastUsedTimestamps: lastUsed
        )
        let recentCanonical = Set(recent.map { RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id) })
        let preferred = preferredWatchExercises(
            from: unique,
            excludingCanonical: recentCanonical,
            lastUsedTimestamps: lastUsed
        )
        let preferredCanonical = Set(preferred.map { RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id) })
        let popular = popularWatchExercises(
            from: unique,
            limit: 20,
            excludingCanonical: recentCanonical.union(preferredCanonical)
        )
        let excludedCanonical = recentCanonical
            .union(preferredCanonical)
            .union(popular.map { RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id) })

        if isSearching || isFilterActive {
            let filtered = filterWatchExercises(
                exercises: unique,
                query: searchText,
                category: selectedCategory
            )
            cachedFiltered = prioritizedWatchExercises(
                filtered,
                recent: recent,
                preferred: preferred,
                popular: popular
            )
            cachedRecent = []
            cachedPreferred = []
            cachedPopular = []
            cachedGrouped = []
        } else {
            cachedFiltered = []
            cachedRecent = recent
            cachedPreferred = preferred
            cachedPopular = popular
            cachedGrouped = groupedWatchExercisesByCategory(
                unique.filter { exercise in
                    !excludedCanonical.contains(RecentExerciseTracker.canonicalExerciseID(exerciseID: exercise.id))
                }
            )
        }
    }
}
