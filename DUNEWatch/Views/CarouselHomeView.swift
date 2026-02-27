import SwiftUI
import SwiftData

// MARK: - Carousel Card Model

/// Represents a single card in the carousel home.
struct CarouselCard: Identifiable, Hashable {
    let id: String
    let section: Section
    let content: Content

    enum Section: String {
        case routine
        case popular
        case recent
        case allExercises
    }

    enum Content: Hashable {
        case exercise(WatchExerciseInfo)
        case routine(name: String, entries: [TemplateEntry])
        case allExercises

        // TemplateEntry is Codable+Identifiable; hash by entry count + name for perf
        func hash(into hasher: inout Hasher) {
            switch self {
            case .exercise(let info):
                hasher.combine("exercise")
                hasher.combine(info.id)
            case .routine(let name, let entries):
                hasher.combine("routine")
                hasher.combine(name)
                hasher.combine(entries.count)
            case .allExercises:
                hasher.combine("all")
            }
        }

        static func == (lhs: Content, rhs: Content) -> Bool {
            switch (lhs, rhs) {
            case (.exercise(let a), .exercise(let b)):
                return a.id == b.id
            case (.routine(let aName, let aEntries), .routine(let bName, let bEntries)):
                return aName == bName && aEntries.count == bEntries.count
            case (.allExercises, .allExercises):
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Shared Helpers

/// Builds subtitle: "3 sets · 10 reps" or "3 sets · 10 reps · 80.0kg"
private func exerciseSubtitle(sets: Int, reps: Int, weight: Double?) -> String {
    var parts = "\(sets) sets · \(reps) reps"
    if let w = weight, w > 0, w <= 500 {
        parts += " · \(w.formattedWeight)kg"
    }
    return parts
}

/// Deduplicates exercises by canonical ID, keeping first occurrence.
private func uniqueByCanonical(_ exercises: [WatchExerciseInfo]) -> [WatchExerciseInfo] {
    var seen = Set<String>()
    return exercises.filter { exercise in
        let canonical = RecentExerciseTracker.canonicalExerciseID(exerciseID: exercise.id)
        return seen.insert(canonical).inserted
    }
}

/// Resolves weight/reps defaults from latest set or exercise defaults.
private func resolvedDefaults(for exercise: WatchExerciseInfo) -> (weight: Double?, reps: Int) {
    let latest = RecentExerciseTracker.latestSet(exerciseID: exercise.id)
    let reps = latest?.reps ?? exercise.defaultReps ?? 10
    let weight = latest?.weight ?? exercise.defaultWeightKg
    return (weight: weight, reps: reps)
}

/// Creates a single-exercise template snapshot for navigation.
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

// MARK: - Carousel Home View

/// Unified Watch home: fullscreen paging carousel combining Routines + Popular + Recent.
/// Replaces the separate RoutineListView + QuickStartPickerView.
struct CarouselHomeView: View {
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var cards: [CarouselCard] = []

    /// Section label/color for each visible card
    private static let sectionConfig: [CarouselCard.Section: (label: String, color: Color)] = [
        .routine: ("Routine", DS.Color.warmGlow),
        .popular: ("Popular", DS.Color.positive),
        .recent: ("Recent", .secondary),
        .allExercises: ("Browse", .secondary),
    ]

    private let popularLimit = 5
    private let recentLimit = 5

    var body: some View {
        Group {
            if cards.isEmpty {
                emptyState
            } else {
                carousel
            }
        }
        .background { WatchWaveBackground() }
        .navigationTitle("DUNE")
        .onAppear { rebuildCards() }
        .onChange(of: templates.count) { _, _ in rebuildCards() }
        .onChange(of: connectivity.exerciseLibrary.count) { _, _ in rebuildCards() }
    }

    // MARK: - Carousel

    private var carousel: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(cards) { card in
                    cardContent(for: card)
                        .containerRelativeFrame(.vertical)
                        .scrollTransition { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                .opacity(phase.isIdentity ? 1.0 : 0.6)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
    }

    // MARK: - Card Content

    @ViewBuilder
    private func cardContent(for card: CarouselCard) -> some View {
        switch card.content {
        case .exercise(let exercise):
            let config = Self.sectionConfig[card.section] ?? ("", .secondary)
            NavigationLink(value: WatchRoute.workoutPreview(snapshotFromExercise(exercise))) {
                ExerciseCardView(
                    exercise: exercise,
                    sectionLabel: config.label,
                    sectionColor: config.color
                )
            }
            .buttonStyle(.plain)

        case .routine(let name, let entries):
            NavigationLink(value: WatchRoute.workoutPreview(
                WorkoutSessionTemplate(name: name, entries: entries)
            )) {
                CarouselRoutineCardView(name: name, entries: entries)
            }
            .buttonStyle(.plain)

        case .allExercises:
            NavigationLink(value: WatchRoute.quickStartAll) {
                allExercisesCard
            }
            .buttonStyle(.plain)
        }
    }

    private var allExercisesCard: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("BROWSE")
                .font(DS.Typography.tinyLabel)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(DS.Color.positive)

            Text("All Exercises")
                .font(.system(.title3, design: .rounded).bold())

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
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

            NavigationLink(value: WatchRoute.quickStartAll) {
                Label("Browse All", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.positive)
            .padding(.top, DS.Spacing.md)

            syncStatusView
                .padding(.top, DS.Spacing.xs)
        }
        .padding()
    }

    // MARK: - Sync Status

    private var syncStatusView: some View {
        HStack(spacing: 4) {
            switch connectivity.syncStatus {
            case .syncing:
                ProgressView()
                    .frame(width: 12, height: 12)
                Text("Syncing...")
            case .synced(let date):
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(DS.Color.positive)
                Text(syncTimeLabel(from: date))
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(DS.Color.caution)
                Text(message)
            case .notConnected:
                Image(systemName: "iphone.slash")
                    .foregroundStyle(.secondary)
                Text("iPhone not connected")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func syncTimeLabel(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just synced"
        } else if interval < 3600 {
            return "\(Int(interval / 60).formattedWithSeparator) min ago"
        } else {
            return "\(Int(interval / 3600).formattedWithSeparator)h ago"
        }
    }

    // MARK: - Rebuild Cards

    /// Builds carousel card array: Routines → Popular → Recent → All Exercises.
    /// @State caching with onChange invalidation (Correction #47, #87).
    private func rebuildCards() {
        var result: [CarouselCard] = []

        // 1. Routine cards (most recently updated first)
        for template in templates {
            result.append(CarouselCard(
                id: "routine-\(template.id)",
                section: .routine,
                content: .routine(name: template.name, entries: template.exerciseEntries)
            ))
        }

        // 2. Popular exercises
        let library = connectivity.exerciseLibrary
        guard !library.isEmpty else {
            // No library synced — show routines (if any) + all exercises card
            result.append(CarouselCard(
                id: "all-exercises",
                section: .allExercises,
                content: .allExercises
            ))
            cards = result
            return
        }

        let popular = Array(
            uniqueByCanonical(
                RecentExerciseTracker.personalizedPopular(from: library, limit: library.count)
            )
            .prefix(popularLimit)
        )

        let popularCanonical = Set(
            popular.map { RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id) }
        )

        for exercise in popular {
            result.append(CarouselCard(
                id: "popular-\(exercise.id)",
                section: .popular,
                content: .exercise(exercise)
            ))
        }

        // 3. Recent exercises (excluding Popular)
        let lastUsed = RecentExerciseTracker.lastUsedTimestamps()
        let recent = Array(
            uniqueByCanonical(
                library
                    .filter { lastUsed[$0.id] != nil }
                    .sorted {
                        let a = lastUsed[$0.id] ?? Date.distantPast.timeIntervalSince1970
                        let b = lastUsed[$1.id] ?? Date.distantPast.timeIntervalSince1970
                        return a > b
                    }
            )
            .filter { !popularCanonical.contains(RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id)) }
            .prefix(recentLimit)
        )

        for exercise in recent {
            result.append(CarouselCard(
                id: "recent-\(exercise.id)",
                section: .recent,
                content: .exercise(exercise)
            ))
        }

        // 4. All Exercises card (always last)
        result.append(CarouselCard(
            id: "all-exercises",
            section: .allExercises,
            content: .allExercises
        ))

        cards = result
    }
}
